# frozen_string_literal: true

# 03 — WhatsApp
#
# Serviço device-based: exige Authorization: Bearer + header DeviceToken.
# O DeviceToken identifica UMA sessão de WhatsApp; o bearer identifica a conta.
#
# Fluxo completo: device → sessão → QR Code → pareamento → envio.
#
#   ruby 03_whatsapp.rb                        # usa o device do .env
#   CRIAR_DEVICE=1 ruby 03_whatsapp.rb         # cria um device novo
#   NUMERO=5511999999999 ruby 03_whatsapp.rb   # e envia de verdade

require "base64"
require_relative "env"

Exemplos.exigir("APIBRASIL_BEARER_TOKEN")

api = ApiBrasil.new
tem_device = !ENV["APIBRASIL_DEVICE_TOKEN"].to_s.empty?

# ---------------------------------------------------------------------------
# 1. O device
# ---------------------------------------------------------------------------
# A SecretKey (painel → API WhatsApp → SecretKey) é a única credencial que cria
# devices. Depois de criado, o device_token substitui ela no dia a dia.
if ENV["CRIAR_DEVICE"] == "1"
  secret_key = Exemplos.exigir("APIBRASIL_SECRET_KEY", "CRIAR_DEVICE=1 precisa dela para criar o device.")

  criado = api.devices.store(
    { "device_name" => "exemplo-ruby", "type" => "server" },
    secret_key: secret_key
  )

  token = criado.dig("device", "device_token")
  puts "Device criado. Guarde este token no seu .env:"
  puts "APIBRASIL_DEVICE_TOKEN=#{token}\n"

  api.set_device_token(token)
  tem_device = true
end

abort "Defina APIBRASIL_DEVICE_TOKEN no .env, ou rode com CRIAR_DEVICE=1." unless tem_device

# ---------------------------------------------------------------------------
# 2. A sessão
# ---------------------------------------------------------------------------
# Os webhooks são opcionais, mas é aqui que se registram — não existe outra
# chamada para isso. Sem eles você só descobre mensagens recebidas por polling.
webhooks = {
  "webhook_wh_message" => ENV["WEBHOOK_MENSAGENS"], # mensagem recebida
  "webhook_wh_status" => ENV["WEBHOOK_STATUS"],     # status da sessão mudou
  "webhook_wh_connect" => ENV["WEBHOOK_CONEXAO"],   # conectou/desconectou
  "webhook_wh_qrcode" => ENV["WEBHOOK_QRCODE"]      # novo QR Code gerado
}.compact

begin
  sessao = api.whatsapp.start(webhooks)
  puts "Sessão: #{sessao['message'] || sessao.inspect}"
rescue ApiBrasil::PermissionError => e
  # 403 aqui é quase sempre DeviceToken de outra API, ou IP fora da whitelist.
  abort "Sem permissão para esse device: #{e.message}"
end

# ---------------------------------------------------------------------------
# 3. O QR Code
# ---------------------------------------------------------------------------
# Vem como data URI base64. Numa aplicação real você joga isso num <img src>;
# aqui gravamos em disco para escanear.
qr = api.whatsapp.qrcode
resposta = qr["response"]
data_uri = resposta.is_a?(Hash) ? resposta["qrcode"] : nil

if data_uri.to_s.start_with?("data:image")
  File.binwrite("qrcode.png", Base64.decode64(data_uri.split(",", 2).last))
  puts "QR Code salvo em qrcode.png — escaneie no WhatsApp → aparelhos conectados."
else
  puts "QR Code: #{(resposta || qr['message'] || 'sessão provavelmente já conectada').inspect}"
end

# ---------------------------------------------------------------------------
# 4. Envios
# ---------------------------------------------------------------------------
numero = ENV["NUMERO"]
unless numero
  puts "\nDefina NUMERO=5511999999999 para enviar de verdade."
  exit 0
end

# Texto. `time_typing` simula "digitando..." antes de entregar.
texto = api.whatsapp.send_text(
  "number" => numero,
  "text" => "Olá! Mensagem enviada pela SDK Ruby da APIBrasil 👋",
  "time_typing" => 1500
)
puts "Texto: #{texto['message'] || texto.inspect}"

# Arquivo por URL pública. Para base64, use send_file64.
api.whatsapp.send_file(
  "number" => numero,
  "path" => "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf",
  "caption" => "Segue o documento"
)

# Áudio (o gateway converte para mp3; máx. 6 min) e localização.
api.whatsapp.send_audio("number" => numero, "path" => "https://filesamples.com/samples/audio/mp3/sample3.mp3")
api.whatsapp.send_location("number" => numero, "lat" => -23.5613, "lng" => -46.6565)

# Qualquer action da documentação, mesmo sem método dedicado na SDK.
api.whatsapp.request("sendLink", "number" => numero, "url" => "https://apibrasil.com.br", "text" => "Conheça")

# Fila: mesma action, processada de forma assíncrona pelo gateway. É o caminho
# certo para disparos em volume — devolve na hora e não segura sua requisição.
enfileirado = api.whatsapp.queue("sendText", "number" => numero, "text" => "Esta foi pela fila 🚀")
puts "Fila: #{enfileirado['message'] || enfileirado.inspect}"

# ---------------------------------------------------------------------------
# 5. Vários devices no mesmo processo
# ---------------------------------------------------------------------------
# with_device devolve um cliente novo, sem alterar o original.
if (suporte_token = ENV["APIBRASIL_DEVICE_TOKEN_SUPORTE"])
  suporte = api.with_device(suporte_token)
  suporte.whatsapp.send_text("number" => numero, "text" => "Falando pela sessão do suporte")
end
