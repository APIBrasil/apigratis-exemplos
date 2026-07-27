#!/usr/bin/env bash
#
# 02 — Consultas por crédito
#
# POST /consulta/{servico}/credits — só precisa do Authorization.
# Debita o saldo da conta e IGNORA o DeviceToken.
#
# Roda em homologação por padrão (sem cobrança). Para valer: COBRAR=1.
#
#   set -a && . ../../.env && set +a
#   bash 02-consultas-por-credito.sh

set -euo pipefail

BASE="${APIBRASIL_BASE_URL:-https://gateway.apibrasil.io/api/v2}"
: "${APIBRASIL_BEARER_TOKEN:?Defina APIBRASIL_BEARER_TOKEN}"

AUTH="Authorization: Bearer ${APIBRASIL_BEARER_TOKEN}"
JSON="Content-Type: application/json"

# `homolog` é o sandbox da plataforma — não existe URL separada de teste.
if [ "${COBRAR:-}" = "1" ]; then
  HOMOLOG=false
  echo "· CONSULTAS REAIS — vai debitar saldo"
else
  HOMOLOG=true
  echo "· modo homologação (sem cobrança)"
fi

consulta() {
  local rotulo="$1" servico="$2" corpo="$3"
  echo
  echo "→ POST /consulta/${servico}/credits — ${rotulo}"
  curl -sS "${BASE}/consulta/${servico}/credits" -H "$AUTH" -H "$JSON" -d "$corpo"
  echo
}

# ---------------------------------------------------------------------------
# CNPJ
# ---------------------------------------------------------------------------
# A resposta traz sempre o mesmo envelope:
# { error, message, balance, tax, valor_consulta, data }
consulta "cadastro básico" cnpj "{\"cnpj\":\"00000000000000\",\"homolog\":${HOMOLOG}}"

# O campo `tipo` escolhe o PRODUTO dentro do serviço: mesmo endpoint, preço e
# retorno diferentes. São 210+ tipos no catálogo.
consulta "lista de sócios" cnpj \
  "{\"cnpj\":\"00000000000000\",\"tipo\":\"lista-socios\",\"homolog\":${HOMOLOG}}"

# ---------------------------------------------------------------------------
# CPF
# ---------------------------------------------------------------------------
consulta "dados cadastrais" cpf "{\"cpf\":\"00000000000\",\"homolog\":${HOMOLOG}}"

# Serasa e afins são `tipo` dentro de /consulta/cpf/credits.
consulta "serasa score" cpf \
  "{\"cpf\":\"00000000000\",\"tipo\":\"serasa-score-pf\",\"homolog\":${HOMOLOG}}"

# ---------------------------------------------------------------------------
# Veicular
# ---------------------------------------------------------------------------
consulta "por placa" veiculos "{\"placa\":\"ABC1234\",\"homolog\":${HOMOLOG}}"

# ---------------------------------------------------------------------------
# Descobrindo o body certo
# ---------------------------------------------------------------------------
# Em vez de adivinhar campos e tomar 422, peça o template ao gateway.
echo
echo "→ GET /endpoint/body — template do body"
curl -sS "${BASE}/endpoint/body?service=cnpj&action=cnpj" -H "$AUTH" || true
echo

# ---------------------------------------------------------------------------
# Rotas descontinuadas
# ---------------------------------------------------------------------------
# Várias rotas antigas viraram 410 com a mensagem apontando a substituta.
# Exemplo: /debitos/cpf/credits → use /consulta/cpf/credits com tipo spc-serasa.
echo
echo "→ POST /debitos/cpf/credits (esperado: 410 com a dica da rota nova)"
curl -sS -w '\n  status: %{http_code}\n' \
  "${BASE}/debitos/cpf/credits" -H "$AUTH" -H "$JSON" -d '{"cpf":"00000000000"}' || true
