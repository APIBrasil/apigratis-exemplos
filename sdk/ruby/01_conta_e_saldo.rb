# frozen_string_literal: true

# 01 — Conta e saldo
#
# O básico: montar o cliente, confirmar que o gateway responde e ler os dados da
# conta. Nada aqui gasta crédito.
#
#   ruby 01_conta_e_saldo.rb

require_relative "env"

# Sem argumentos, o cliente lê APIBRASIL_BEARER_TOKEN, APIBRASIL_DEVICE_TOKEN,
# APIBRASIL_SECRET_KEY e APIBRASIL_BASE_URL do ambiente.
api = ApiBrasil.new

# /status é público — separa "minha credencial está errada" de "o gateway caiu".
status = api.catalog.status
puts "Gateway: #{status['message'] || status.inspect}"

Exemplos.exigir("APIBRASIL_BEARER_TOKEN")

begin
  puts "Saldo: #{api.account.balance.inspect}"
  puts "Plano: #{api.account.plan.inspect}"

  # Devices ativos na conta — cada um é uma instância de um serviço.
  devices = api.devices.list["devices"] || []
  puts "\n#{devices.length} device(s):"
  devices.each do |device|
    servico = device.dig("api", "name") || "—"
    puts "  #{device['device_name'] || '—'} · #{servico} · #{device['status'] || '—'}"
  end
rescue ApiBrasil::AuthenticationError
  abort "Bearer inválido ou expirado — refaça o login no painel."
rescue ApiBrasil::ApiBrasilError => e
  abort "Falhou (HTTP #{e.status}): #{e.message}"
end

# Login por email/senha, se você preferir não guardar o JWT:
#
#   api = ApiBrasil.new
#   sessao = api.auth.login("email" => email, "password" => senha)
#   if sessao["requires_2fa"]
#     api.auth.send_2fa("challenge" => sessao["challenge"], "method" => "email")
#     api.auth.verify_2fa("challenge" => sessao["challenge"], "code" => "000000")
#   end
#   # o token já ficou guardado no cliente — siga usando `api` normalmente
