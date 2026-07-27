# frozen_string_literal: true

# 02 — Consultas por crédito
#
# Rotas /consulta/{servico}/credits. Só precisam do bearer: debitam o saldo da
# conta e ignoram o DeviceToken.
#
# Roda em HOMOLOGAÇÃO por padrão (dados fictícios, sem cobrança).
# Para valer, rode com COBRAR=1.
#
#   ruby 02_consultas_por_credito.rb
#   COBRAR=1 ruby 02_consultas_por_credito.rb

require "json"
require_relative "env"

Exemplos.exigir("APIBRASIL_BEARER_TOKEN")

api = ApiBrasil.new

# `homolog` é o sandbox da plataforma — não existe URL separada de teste.
homolog = ENV["COBRAR"] != "1"
puts homolog ? "· modo homologação (sem cobrança)\n" : "· CONSULTAS REAIS — vai debitar saldo\n"

# Toda consulta devolve o mesmo envelope:
# { error, message, balance, tax, valor_consulta, data }.
def resumir(rotulo, resposta)
  puts "#{rotulo}:"
  puts "  custou: #{resposta['valor_consulta'] || '—'} | saldo restante: #{resposta['balance'] || '—'}"
  puts "  data: #{JSON.generate(resposta['data'])[0, 300]}"
end

begin
  # CNPJ — cadastro básico.
  resumir("CNPJ", api.consulta.cnpj("cnpj" => "00000000000000", "homolog" => homolog))

  # O campo `tipo` é o que escolhe o PRODUTO dentro do serviço. Mesmo endpoint,
  # preço e retorno diferentes. São 210+ tipos no catálogo.
  resumir("CNPJ · lista-socios", api.consulta.cnpj(
                                   "cnpj" => "00000000000000",
                                   "tipo" => "lista-socios",
                                   "homolog" => homolog
                                 ))

  # CPF.
  resumir("CPF", api.consulta.cpf("cpf" => "00000000000", "homolog" => homolog))

  # Veicular por placa.
  resumir("Veículos", api.consulta.veiculos("placa" => "ABC1234", "homolog" => homolog))

  # Qualquer serviço do catálogo, inclusive os sem método dedicado.
  resumir("Serasa Score PF", api.consulta.generic("cpf",
                                                  "cpf" => "00000000000",
                                                  "tipo" => "serasa-score-pf",
                                                  "homolog" => homolog))

  # Descobrindo o que existe: catálogo vivo do gateway.
  apis = api.catalog.apis("consulta")["apis"] || []
  puts "\n#{apis.length} API(s) com \"consulta\" no nome. Primeiras:"
  apis.first(5).each { |item| puts "  #{item['name'] || '—'} · R$ #{item['price'] || '—'}" }
rescue ApiBrasil::InsufficientBalanceError => e
  # 402 — a mensagem do gateway já traz o valor exato da consulta.
  abort "Sem saldo: #{e.message}"
rescue ApiBrasil::ValidationError => e
  # 422 — o template do body está em GET /api/v2/endpoint/body.
  abort "Body inválido: #{e.message} — #{e.response.inspect}"
end
