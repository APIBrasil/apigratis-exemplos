#!/usr/bin/env bash
#
# 04 — Serviços device-based (fora do WhatsApp)
#
# Todos no mesmo formato: POST /{servico}/{action} com Authorization + DeviceToken.
# O device precisa ser da API correspondente — um DeviceToken de WhatsApp dá 403
# em /vehicles.
#
#   set -a && . ../../.env && set +a
#   bash 04-servicos-device.sh

set -euo pipefail

BASE="${APIBRASIL_BASE_URL:-https://gateway.apibrasil.io/api/v2}"
: "${APIBRASIL_BEARER_TOKEN:?Defina APIBRASIL_BEARER_TOKEN}"

AUTH="Authorization: Bearer ${APIBRASIL_BEARER_TOKEN}"
JSON="Content-Type: application/json"

# Cada API tem o seu device. Sobrescreva por serviço se você tiver vários:
#   APIBRASIL_DEVICE_TOKEN_CEP, _CORREIOS, _VEICULOS, _CLIMA, _SMS
device_de() {
  local especifico
  especifico=$(eval "echo \${APIBRASIL_DEVICE_TOKEN_$1:-}")
  echo "DeviceToken: ${especifico:-${APIBRASIL_DEVICE_TOKEN:-}}"
}

chamar() {
  local rotulo="$1" caminho="$2" corpo="$3" device="$4"
  echo
  echo "→ POST ${caminho} — ${rotulo}"
  curl -sS -w '\n  status: %{http_code}\n' \
    "${BASE}${caminho}" -H "$AUTH" -H "$device" -H "$JSON" -d "$corpo" || true
}

# ---------------------------------------------------------------------------
# CEP — endereço completo com geolocalização
# ---------------------------------------------------------------------------
chamar "CEP" /cep/cep '{"cep":"01001000"}' "$(device_de CEP)"

# O serviço /cep tem mais actions: cidadesPorDDD, bairros, cidades, estados.
chamar "cidades por DDD" /cep/cidadesPorDDD '{"ddd":"11"}' "$(device_de CEP)"

# ---------------------------------------------------------------------------
# Correios — rastreio
# ---------------------------------------------------------------------------
chamar "rastreio" /correios/rastreio '{"code":"AA123456789BR"}' "$(device_de CORREIOS)"

# ---------------------------------------------------------------------------
# Veículos por placa
# ---------------------------------------------------------------------------
# Note a diferença: /vehicles/* é device-based; /consulta/veiculos/credits
# debita saldo. Mesma informação, cobrança diferente.
chamar "placa · dados" /vehicles/dados '{"placa":"ABC1234"}' "$(device_de VEICULOS)"
chamar "placa · FIPE" /vehicles/fipe '{"placa":"ABC1234"}' "$(device_de VEICULOS)"

# ---------------------------------------------------------------------------
# Tabela FIPE — navegável: referência → marcas → modelos → ano → valor
# ---------------------------------------------------------------------------
chamar "FIPE · tabela de referência" /fipe/ConsultarTabelaDeReferencia '{}' "$(device_de VEICULOS)"
chamar "FIPE · marcas" /fipe/ConsultarMarcas \
  '{"codigoTabelaReferencia":300,"codigoTipoVeiculo":1}' "$(device_de VEICULOS)"

# ---------------------------------------------------------------------------
# Clima, feriados, DDD, tradução
# ---------------------------------------------------------------------------
chamar "clima por cidade" /weather/city '{"city":"São Paulo"}' "$(device_de CLIMA)"
chamar "feriados do ano" /holidays/feriados "{\"year\":$(date +%Y)}" "$(device_de CLIMA)"

# ---------------------------------------------------------------------------
# GeoIP
# ---------------------------------------------------------------------------
chamar "GeoIP" /database/ip '{"ip":"8.8.8.8"}' "$(device_de CEP)"

# ---------------------------------------------------------------------------
# SMS
# ---------------------------------------------------------------------------
if [ -n "${NUMERO:-}" ]; then
  chamar "SMS" /sms/send \
    "{\"number\":\"${NUMERO}\",\"message\":\"Seu código: 123456\"}" "$(device_de SMS)"

  # Versão que debita créditos em vez de usar device (não manda DeviceToken):
  # curl -sS "${BASE}/sms/send/credits" -H "$AUTH" -H "$JSON" \
  #   -d "{\"number\":\"${NUMERO}\",\"message\":\"Olá!\"}"
fi
