# frozen_string_literal: true

# 04 — Serviços device-based (fora do WhatsApp)
#
# Todos seguem o mesmo formato: POST /{servico}/{action} com Bearer + DeviceToken.
# O device precisa ser da API correspondente — um DeviceToken de WhatsApp dá 403
# em /vehicles.
#
#   ruby 04_servicos_device.rb

require "json"
require_relative "env"

Exemplos.exigir("APIBRASIL_BEARER_TOKEN")

api = ApiBrasil.new

# Cada API tem o seu device. Rode com o token certo por serviço, ou passe
# `device_token:` na chamada — que é o que fazemos aqui.
PADRAO = ENV.fetch("APIBRASIL_DEVICE_TOKEN", nil)
DEVICES = {
  cep: ENV["APIBRASIL_DEVICE_TOKEN_CEP"] || PADRAO,
  correios: ENV["APIBRASIL_DEVICE_TOKEN_CORREIOS"] || PADRAO,
  veiculos: ENV["APIBRASIL_DEVICE_TOKEN_VEICULOS"] || PADRAO,
  clima: ENV["APIBRASIL_DEVICE_TOKEN_CLIMA"] || PADRAO,
  sms: ENV["APIBRASIL_DEVICE_TOKEN_SMS"] || PADRAO
}.freeze

# Roda um bloco e reporta a falha sem derrubar os outros exemplos.
def tentar(rotulo)
  resposta = yield
  corpo = resposta.is_a?(Hash) ? (resposta["response"] || resposta) : resposta
  puts "\n#{rotulo}:"
  puts JSON.pretty_generate(corpo)[0, 600]
rescue ApiBrasil::NotFoundError => e
  puts "\n#{rotulo}: sem dados (HTTP #{e.status})"
rescue ApiBrasil::ApiBrasilError => e
  puts "\n#{rotulo}: #{e.message} (HTTP #{e.status})"
end

# CEP — endereço completo com geolocalização.
tentar("CEP") { api.cep.cep({ "cep" => "01001000" }, device_token: DEVICES[:cep]) }

# Ainda em /cep: cidades por DDD, bairros, cidades, estados, distância.
tentar("Cidades por DDD") { api.cep.request("cidadesPorDDD", { "ddd" => "11" }, device_token: DEVICES[:cep]) }

# Correios — rastreio de encomenda.
tentar("Rastreio") { api.correios.rastreio({ "code" => "AA123456789BR" }, device_token: DEVICES[:correios]) }

# Veículos por placa. Diferente de consulta.veiculos (créditos): aqui é device.
tentar("Placa · dados") { api.vehicles.dados({ "placa" => "ABC1234" }, device_token: DEVICES[:veiculos]) }
tentar("Placa · FIPE") { api.vehicles.fipe({ "placa" => "ABC1234" }, device_token: DEVICES[:veiculos]) }

# Tabela FIPE navegável: referência → marcas → modelos → ano → valor.
tentar("FIPE · marcas") do
  api.fipe.marcas(
    { "codigoTabelaReferencia" => 300, "codigoTipoVeiculo" => 1 },
    device_token: DEVICES[:veiculos]
  )
end

# Clima por cidade ou por coordenadas.
tentar("Clima") { api.weather.city({ "city" => "São Paulo" }, device_token: DEVICES[:clima]) }

# Feriados do ano. `request` cobre qualquer action, com ou sem método dedicado.
tentar("Feriados") do
  api.holidays.request("feriados", { "year" => Time.now.year }, device_token: DEVICES[:clima])
end

# GeoIP.
tentar("GeoIP") { api.database_ip.ip({ "ip" => "8.8.8.8" }, device_token: DEVICES[:cep]) }

# SMS — device-based. Só envia de verdade com NUMERO definido.
if (numero = ENV["NUMERO"])
  tentar("SMS") do
    api.sms.send_message(
      { "number" => numero, "message" => "Seu código: 123456" },
      device_token: DEVICES[:sms]
    )
  end

  # Alternativa sem device, debitando créditos da conta:
  # api.sms.send_with_credits("number" => numero, "message" => "Olá!")
end

# Serviço sem método dedicado? A saída genérica cobre o gateway inteiro.
# api.request("POST", "/translate/text", { "text" => "Olá", "to" => "en" })
