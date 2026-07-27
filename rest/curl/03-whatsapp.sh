#!/usr/bin/env bash
#
# 03 — WhatsApp
#
# Serviço device-based: Authorization + DeviceToken.
# O fluxo é device → sessão → QR Code → pareamento → envio.
#
#   set -a && . ../../.env && set +a
#   bash 03-whatsapp.sh
#   CRIAR_DEVICE=1 bash 03-whatsapp.sh
#   NUMERO=5511999999999 bash 03-whatsapp.sh

set -euo pipefail

BASE="${APIBRASIL_BASE_URL:-https://gateway.apibrasil.io/api/v2}"
: "${APIBRASIL_BEARER_TOKEN:?Defina APIBRASIL_BEARER_TOKEN}"

AUTH="Authorization: Bearer ${APIBRASIL_BEARER_TOKEN}"
JSON="Content-Type: application/json"

# ---------------------------------------------------------------------------
# 1. O device
# ---------------------------------------------------------------------------
# ESTE é o único lugar onde o header SecretKey tem função: criar um device.
# Em /whatsapp/sendText e afins, SecretKey não serve para nada.
if [ "${CRIAR_DEVICE:-}" = "1" ]; then
  : "${APIBRASIL_SECRET_KEY:?CRIAR_DEVICE=1 exige APIBRASIL_SECRET_KEY}"

  echo "→ POST /devices/store"
  RESPOSTA=$(curl -sS "${BASE}/devices/store" \
    -H "$AUTH" -H "$JSON" \
    -H "SecretKey: ${APIBRASIL_SECRET_KEY}" \
    -d '{"device_name":"exemplo-curl","type":"server"}')

  echo "$RESPOSTA"

  APIBRASIL_DEVICE_TOKEN=$(echo "$RESPOSTA" \
    | grep -oE '"device_token":"[^"]+"' | head -n 1 | cut -d'"' -f4)

  echo
  echo "  Guarde no .env: APIBRASIL_DEVICE_TOKEN=${APIBRASIL_DEVICE_TOKEN}"
fi

: "${APIBRASIL_DEVICE_TOKEN:?Defina APIBRASIL_DEVICE_TOKEN, ou rode com CRIAR_DEVICE=1}"
DEVICE="DeviceToken: ${APIBRASIL_DEVICE_TOKEN}"

# ---------------------------------------------------------------------------
# 2. A sessão
# ---------------------------------------------------------------------------
# Os webhooks são opcionais, mas é aqui que se registram — não existe outra
# chamada para isso.
echo
echo "→ POST /whatsapp/start"
curl -sS "${BASE}/whatsapp/start" -H "$AUTH" -H "$DEVICE" -H "$JSON" -d "{
  \"webhook_wh_message\": \"${WEBHOOK_MENSAGENS:-}\",
  \"webhook_wh_status\": \"${WEBHOOK_STATUS:-}\",
  \"webhook_wh_connect\": \"${WEBHOOK_CONEXAO:-}\",
  \"webhook_wh_qrcode\": \"${WEBHOOK_QRCODE:-}\"
}"
echo

# ---------------------------------------------------------------------------
# 3. O QR Code
# ---------------------------------------------------------------------------
# Vem em response.qrcode como data URI base64. As primeiras linhas abaixo
# mostram só o começo — o data URI inteiro tem alguns KB.
echo
echo "→ POST /whatsapp/qrcode"
curl -sS "${BASE}/whatsapp/qrcode" -H "$AUTH" -H "$DEVICE" -H "$JSON" -d '{}' | head -c 400
echo
echo "  (…truncado. Com jq: | jq -r '.response.qrcode' | cut -d, -f2 | base64 -d > qrcode.png)"

# Status da conexão — para saber se já pareou.
echo
echo "→ POST /whatsapp/getConnectionStatus"
curl -sS "${BASE}/whatsapp/getConnectionStatus" -H "$AUTH" -H "$DEVICE" -H "$JSON" -d '{}'
echo

# ---------------------------------------------------------------------------
# 4. Envios
# ---------------------------------------------------------------------------
if [ -z "${NUMERO:-}" ]; then
  echo
  echo "Defina NUMERO=5511999999999 para enviar de verdade."
  exit 0
fi

echo
echo "→ POST /whatsapp/sendText"
curl -sS "${BASE}/whatsapp/sendText" -H "$AUTH" -H "$DEVICE" -H "$JSON" -d "{
  \"number\": \"${NUMERO}\",
  \"text\": \"Olá! Enviado com curl 👋\",
  \"time_typing\": 1500
}"
echo

# Arquivo por URL pública. Para base64, use /whatsapp/sendFile64.
echo
echo "→ POST /whatsapp/sendFile"
curl -sS "${BASE}/whatsapp/sendFile" -H "$AUTH" -H "$DEVICE" -H "$JSON" -d "{
  \"number\": \"${NUMERO}\",
  \"path\": \"https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf\",
  \"caption\": \"Segue o documento\"
}"
echo

# ---------------------------------------------------------------------------
# 5. Fila
# ---------------------------------------------------------------------------
# Sufixo /queue em qualquer action: o gateway processa de forma assíncrona.
# É o caminho para disparos em volume — responde na hora.
echo
echo "→ POST /whatsapp/sendText/queue"
curl -sS "${BASE}/whatsapp/sendText/queue" -H "$AUTH" -H "$DEVICE" -H "$JSON" -d "{
  \"number\": \"${NUMERO}\",
  \"text\": \"Esta foi pela fila 🚀\"
}"
echo

# ---------------------------------------------------------------------------
# Evolution API
# ---------------------------------------------------------------------------
# Rota com um nível a mais: /evolution/{controller}/{action}.
# echo
# echo "→ POST /evolution/message/sendText"
# curl -sS "${BASE}/evolution/message/sendText" -H "$AUTH" -H "$DEVICE" -H "$JSON" -d "{
#   \"number\": \"${NUMERO}\",
#   \"options\": { \"delay\": 1200, \"presence\": \"composing\" },
#   \"textMessage\": { \"text\": \"Via Evolution\" }
# }"
