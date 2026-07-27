#!/usr/bin/env bash
#
# 01 — Login e saldo
#
# Mostra de onde vem o Bearer Token e como confirmar que ele está válido.
#
#   set -a && . ../../.env && set +a
#   bash 01-login-e-saldo.sh

set -euo pipefail

BASE="${APIBRASIL_BASE_URL:-https://gateway.apibrasil.io/api/v2}"

# ---------------------------------------------------------------------------
# Status do gateway — rota pública, sem credencial
# ---------------------------------------------------------------------------
# Serve para separar "minha credencial está errada" de "o gateway caiu".
echo "→ GET /status"
curl -sS "${BASE}/status"
echo

# ---------------------------------------------------------------------------
# Login — só se você ainda não tem o bearer
# ---------------------------------------------------------------------------
# O JWT também está no painel (credenciais). O login é útil para renovar.
if [ -z "${APIBRASIL_BEARER_TOKEN:-}" ]; then
  : "${APIBRASIL_EMAIL:?Defina APIBRASIL_BEARER_TOKEN, ou APIBRASIL_EMAIL + APIBRASIL_PASSWORD}"
  : "${APIBRASIL_PASSWORD:?Defina APIBRASIL_PASSWORD}"

  echo
  echo "→ POST /login"
  RESPOSTA=$(curl -sS "${BASE}/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${APIBRASIL_EMAIL}\",\"password\":\"${APIBRASIL_PASSWORD}\"}")

  # Extrai o token sem depender de jq. Com jq instalado, prefira:
  #   APIBRASIL_BEARER_TOKEN=$(echo "$RESPOSTA" | jq -r '.token // .bearer')
  APIBRASIL_BEARER_TOKEN=$(echo "$RESPOSTA" \
    | grep -oE '"(token|bearer)":"[^"]+"' \
    | head -n 1 | cut -d'"' -f4)

  if [ -z "$APIBRASIL_BEARER_TOKEN" ]; then
    echo "Não recebi o token. Resposta:" >&2
    echo "$RESPOSTA" >&2
    # Conta com 2FA responde requires_2fa + challenge; conclua em
    # POST /auth/2fa/send e POST /auth/login/verify-2fa.
    exit 1
  fi

  echo "  Token obtido. Guarde no .env:"
  echo "  APIBRASIL_BEARER_TOKEN=${APIBRASIL_BEARER_TOKEN}"
fi

AUTH="Authorization: Bearer ${APIBRASIL_BEARER_TOKEN}"

# ---------------------------------------------------------------------------
# Saldo e plano
# ---------------------------------------------------------------------------
echo
echo "→ GET /balance"
curl -sS "${BASE}/balance" -H "$AUTH"
echo

echo
echo "→ GET /plan"
curl -sS "${BASE}/plan" -H "$AUTH"
echo

# ---------------------------------------------------------------------------
# Devices da conta
# ---------------------------------------------------------------------------
# Cada device é uma instância de um serviço. É daqui que sai o DeviceToken.
echo
echo "→ GET /devices"
curl -sS "${BASE}/devices" -H "$AUTH"
echo

# ---------------------------------------------------------------------------
# Catálogo — o que a sua conta pode consumir
# ---------------------------------------------------------------------------
echo
echo "→ GET /apis?search=cep"
curl -sS "${BASE}/apis?search=cep" -H "$AUTH"
echo
