#!/usr/bin/env bash
#
# Sessão MCP completa com curl: initialize → tools/list → tools/call.
#
#   export APIBRASIL_BEARER_TOKEN=...
#   bash sessao.sh
#
# Contra um servidor local:
#   APIBRASIL_MCP_URL=http://localhost:3030/mcp bash sessao.sh

set -euo pipefail

MCP_URL="${APIBRASIL_MCP_URL:-https://mcp.apibrasil.cloud/mcp}"
BEARER="${APIBRASIL_BEARER_TOKEN:?Defina APIBRASIL_BEARER_TOKEN}"
DEVICE_TOKEN="${APIBRASIL_DEVICE_TOKEN:-}"

# O Streamable HTTP pode responder JSON ou abrir um stream SSE — anuncie os dois.
CABECALHOS=(
  -H "Content-Type: application/json"
  -H "Accept: application/json, text/event-stream"
  -H "X-Apibrasil-Bearer: ${BEARER}"
)
[ -n "$DEVICE_TOKEN" ] && CABECALHOS+=(-H "DeviceToken: ${DEVICE_TOKEN}")
# Autenticação do próprio servidor MCP, se o deploy exigir (MCP_AUTH_TOKEN):
[ -n "${APIBRASIL_MCP_TOKEN:-}" ] && CABECALHOS+=(-H "Authorization: Bearer ${APIBRASIL_MCP_TOKEN}")

# A resposta pode vir como SSE (`event: message` + `data: {...}`) — normaliza
# para o JSON puro nos dois casos.
corpo_json() {
  sed -n 's/^data: //p' | tail -n 1
}

# ---------------------------------------------------------------------------
# 1. initialize — a resposta traz o Mcp-Session-Id NO HEADER
# ---------------------------------------------------------------------------
echo "→ initialize em ${MCP_URL}"

CABECALHOS_RESPOSTA=$(mktemp)
trap 'rm -f "$CABECALHOS_RESPOSTA"' EXIT

RESPOSTA=$(curl -sS -D "$CABECALHOS_RESPOSTA" "${CABECALHOS[@]}" "$MCP_URL" -d @- <<'JSON'
{
  "jsonrpc": "2.0",
  "id": "init",
  "method": "initialize",
  "params": {
    "protocolVersion": "2025-06-18",
    "clientInfo": { "name": "curl", "version": "1.0.0" },
    "capabilities": {}
  }
}
JSON
)

SESSAO=$(grep -i '^mcp-session-id:' "$CABECALHOS_RESPOSTA" | tr -d '\r' | cut -d' ' -f2-)

if [ -z "$SESSAO" ]; then
  echo "Não recebi Mcp-Session-Id. Resposta:" >&2
  echo "$RESPOSTA" >&2
  exit 1
fi

echo "  Mcp-Session-Id: ${SESSAO}"
CABECALHOS+=(-H "Mcp-Session-Id: ${SESSAO}")

# ---------------------------------------------------------------------------
# 2. notifications/initialized — fecha o handshake
# ---------------------------------------------------------------------------
curl -sS -o /dev/null "${CABECALHOS[@]}" "$MCP_URL" \
  -d '{"jsonrpc":"2.0","method":"notifications/initialized"}'

# ---------------------------------------------------------------------------
# 3. tools/list
# ---------------------------------------------------------------------------
echo
echo "→ tools/list"
curl -sS "${CABECALHOS[@]}" "$MCP_URL" -d @requisicoes/tools-list.json \
  | corpo_json \
  | grep -o '"name":"[^"]*"' \
  | head -30

# ---------------------------------------------------------------------------
# 4. tools/call — saldo da conta (leitura pura)
# ---------------------------------------------------------------------------
echo
echo "→ tools/call apibrasil.balance.get"
curl -sS "${CABECALHOS[@]}" "$MCP_URL" -d @requisicoes/balance.json | corpo_json

# ---------------------------------------------------------------------------
# 5. tools/call — consulta CNPJ em homologação (sem cobrança)
# ---------------------------------------------------------------------------
echo
echo "→ tools/call apibrasil.credits.consulta (homologação)"
curl -sS "${CABECALHOS[@]}" "$MCP_URL" -d @requisicoes/consulta-cnpj.json | corpo_json

# ---------------------------------------------------------------------------
# 6. prompts e resources
# ---------------------------------------------------------------------------
echo
echo "→ prompts/list"
curl -sS "${CABECALHOS[@]}" "$MCP_URL" -d @requisicoes/prompts-list.json \
  | corpo_json | grep -o '"name":"[^"]*"' | head -20

echo
echo "→ resources/list"
curl -sS "${CABECALHOS[@]}" "$MCP_URL" -d @requisicoes/resources-list.json | corpo_json

# ---------------------------------------------------------------------------
# 7. health — sem sessão nem autenticação
# ---------------------------------------------------------------------------
echo
echo "→ GET /health"
curl -sS "${MCP_URL%/mcp}/health" || true
echo
