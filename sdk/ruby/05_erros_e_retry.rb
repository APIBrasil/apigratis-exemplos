# frozen_string_literal: true

# 05 — Erros, retry e observabilidade
#
# A parte que separa um script de uma integração de produção.
#
#   ruby 05_erros_e_retry.rb

require_relative "env"

Exemplos.exigir("APIBRASIL_BEARER_TOKEN")

# ---------------------------------------------------------------------------
# Retry
# ---------------------------------------------------------------------------
# O padrão são 2 tentativas extras, backoff exponencial, SÓ em 429 e falha de
# conexão — e respeitando o Retry-After da resposta.
#
# Timeout e erro de negócio nunca são repetidos: um send_text que deu timeout
# pode ter sido entregue, e uma consulta repetida cobra duas vezes.
api = ApiBrasil.new(
  timeout: 30_000, # milissegundos
  retry: {
    retries: 3,
    min_delay_ms: 500,
    retry_on_statuses: [429, 503]
  },
  # Hooks: é aqui que você pluga log estruturado, métricas ou tracing.
  hooks: {
    on_request: ->(i) { puts "→ #{i[:method]} #{i[:url]} (tentativa #{i[:attempt]})" },
    on_response: ->(i) { puts "← #{i[:status]} em #{i[:duration_ms]}ms" },
    on_retry: ->(i) { warn "↻ retry em #{i[:delay_ms]}ms: #{i[:reason]}" }
  }
)

# Para desligar: retry: false.

# ---------------------------------------------------------------------------
# Erros
# ---------------------------------------------------------------------------
# Cada status HTTP do gateway vira uma classe. Todas estendem
# ApiBrasil::ApiBrasilError e expõem #status, #error_code, #message e #response.
begin
  api.consulta.cpf("cpf" => "00000000000")
rescue ApiBrasil::ValidationError => e
  # 400/422 — o body está errado. O template certo vem de
  # GET /api/v2/endpoint/body, e a doc está em doc.apibrasil.io.
  warn "Payload inválido: #{e.message} — #{e.response.inspect}"
rescue ApiBrasil::AuthenticationError
  # 401 — bearer ausente/expirado. Refaça o login; não faça retry cego.
  warn "Refaça o login."
rescue ApiBrasil::InsufficientBalanceError => e
  # 402 — a mensagem já traz o valor exato da consulta que faltou.
  warn "Recarregue: #{e.message}"
rescue ApiBrasil::PermissionError => e
  # 403 — DeviceToken de outra API, IP fora da whitelist, ou API que exige
  # cadastro PJ. São três causas com o mesmo status: leia a mensagem.
  warn "Sem permissão: #{e.message}"
rescue ApiBrasil::NotFoundError => e
  # 404 = não achou o dado. 410 = rota desativada, e a mensagem aponta a nova.
  warn "#{e.status == 410 ? 'Rota descontinuada' : 'Sem dados'}: #{e.message}"
rescue ApiBrasil::RateLimitError => e
  # 429 — a SDK já tentou de novo antes de chegar aqui.
  warn "Limite atingido. Aguarde #{e.retry_after_ms}ms."
rescue ApiBrasil::ServerError => e
  # 5xx — gateway ou provedor upstream. Repetir com backoff faz sentido.
  warn "Falha do servidor: #{e.status} #{e.message}"
rescue ApiBrasil::TimeoutError
  # Estourou o tempo. ATENÇÃO: a operação pode ter completado no servidor.
  # Em envios e consultas, confirme o estado antes de repetir.
  warn "Timeout — verifique o estado antes de tentar de novo."
rescue ApiBrasil::NetworkError => e
  # Não chegou a haver resposta: DNS, TLS, conexão recusada.
  warn "Falha de rede: #{e.message}"
rescue ApiBrasil::ApiBrasilError => e
  warn "Erro da SDK (HTTP #{e.status}, código #{e.error_code}): #{e.message}"
end

# ---------------------------------------------------------------------------
# Idempotência na prática
# ---------------------------------------------------------------------------
# Operações que cobram ou enviam merecem cuidado extra. O padrão abaixo repete
# só o que é seguro repetir.
#
# Ordem importa: TimeoutError herda de NetworkError, então o rescue dele vem
# primeiro — indica trabalho possivelmente concluído no servidor.
def com_retry_seguro(tentativas: 3)
  tentativa = 0
  begin
    tentativa += 1
    yield
  rescue ApiBrasil::TimeoutError
    raise
  rescue ApiBrasil::ServerError, ApiBrasil::NetworkError
    raise if tentativa >= tentativas

    sleep((2**tentativa) * 0.25)
    retry
  end
end

begin
  puts "\nSaldo: #{com_retry_seguro { api.account.balance }.inspect}"
rescue ApiBrasil::ApiBrasilError => e
  warn "Desisti: #{e.message}"
end
