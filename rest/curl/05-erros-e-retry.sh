#!/usr/bin/env bash
#
# 05 — Erros e retry sem SDK
#
# Sem SDK, o retry é seu. Duas regras que valem dinheiro:
#   1. Repita só em 429 e falha de conexão. Respeite o Retry-After.
#   2. NUNCA repita timeout às cegas — a operação pode ter completado, e você
#      duplica uma mensagem enviada ou uma consulta cobrada.
#
#   set -a && . ../../.env && set +a
#   bash 05-erros-e-retry.sh

set -uo pipefail   # sem -e: aqui a gente QUER inspecionar as falhas

BASE="${APIBRASIL_BASE_URL:-https://gateway.apibrasil.io/api/v2}"
: "${APIBRASIL_BEARER_TOKEN:?Defina APIBRASIL_BEARER_TOKEN}"

AUTH="Authorization: Bearer ${APIBRASIL_BEARER_TOKEN}"
JSON="Content-Type: application/json"

# ---------------------------------------------------------------------------
# Separando status de corpo
# ---------------------------------------------------------------------------
# -w '\n%{http_code}' põe o status na última linha: dá para ramificar no shell
# sem perder a mensagem do gateway (que é a parte útil).
explicar() {
  local caminho="$1" corpo="$2"

  local resposta status conteudo
  resposta=$(curl -sS -w '\n%{http_code}' "${BASE}${caminho}" -H "$AUTH" -H "$JSON" -d "$corpo")
  status=$(echo "$resposta" | tail -n 1)
  conteudo=$(echo "$resposta" | sed '$d')

  echo
  echo "→ POST ${caminho} → HTTP ${status}"

  case "$status" in
    2*)  echo "  ok: $(echo "$conteudo" | head -c 200)" ;;
    400|422)
         # Payload inválido. GET /endpoint/body dá o template certo.
         echo "  payload inválido: $conteudo" ;;
    401) # Bearer ausente/expirado. Refaça o login; não tente de novo igual.
         echo "  refaça o login" ;;
    402) # Sem saldo. A mensagem traz o valor exato da consulta.
         echo "  sem saldo: $conteudo" ;;
    403) # Três causas com o mesmo status: DeviceToken de outra API, IP fora da
         # whitelist, ou API que exige cadastro PJ. Leia a mensagem.
         echo "  sem permissão: $conteudo" ;;
    404) echo "  sem dados" ;;
    410) # Rota desativada — a mensagem aponta a substituta.
         echo "  rota descontinuada: $conteudo" ;;
    429) # Limite por minuto. Respeite o Retry-After (veja abaixo).
         echo "  limite atingido: $conteudo" ;;
    5*)  echo "  falha do servidor — retry com backoff faz sentido" ;;
    000) # curl não conseguiu resposta: DNS, TLS, conexão recusada, timeout.
         echo "  sem resposta (rede ou timeout)" ;;
    *)   echo "  $conteudo" ;;
  esac
}

# Body vazio → 422 com a lista de campos que faltam.
explicar /consulta/cnpj/credits '{}'

# Rota desativada → 410 apontando a nova.
explicar /debitos/cpf/credits '{"cpf":"00000000000"}'

# Device-based sem DeviceToken → 403.
explicar /whatsapp/sendText '{"number":"5511999999999","text":"teste"}'

# ---------------------------------------------------------------------------
# Lendo o Retry-After num 429
# ---------------------------------------------------------------------------
# O valor vem no header, então precisa de -D (dump headers).
echo
echo "→ como ler o Retry-After"
echo '  curl -sS -D - "$BASE/balance" -H "$AUTH" | grep -i "^retry-after:"'

# ---------------------------------------------------------------------------
# Retry que não duplica cobrança
# ---------------------------------------------------------------------------
# Repete em 429 e 5xx. Um timeout do curl (status 000 com --max-time) NÃO é
# repetido: a requisição pode ter chegado ao gateway e completado.
com_retry() {
  local caminho="$1" corpo="$2" tentativas="${3:-3}"

  local i status resposta conteudo espera
  for (( i = 1; i <= tentativas; i++ )); do
    resposta=$(curl -sS -D /tmp/apibrasil-headers -w '\n%{http_code}' --max-time 30 \
      "${BASE}${caminho}" -H "$AUTH" -H "$JSON" -d "$corpo")
    status=$(echo "$resposta" | tail -n 1)
    conteudo=$(echo "$resposta" | sed '$d')

    case "$status" in
      2*)
        echo "$conteudo"
        return 0
        ;;
      429)
        # Respeitar o Retry-After do servidor é melhor que adivinhar.
        espera=$(grep -i '^retry-after:' /tmp/apibrasil-headers 2>/dev/null \
          | tr -d '\r' | awk '{print $2}')
        espera=${espera:-$(( 2 ** i ))}
        echo "  429 — aguardando ${espera}s (tentativa ${i}/${tentativas})" >&2
        sleep "$espera"
        ;;
      5*)
        echo "  ${status} — backoff $(( 2 ** i ))s (tentativa ${i}/${tentativas})" >&2
        sleep $(( 2 ** i ))
        ;;
      000)
        # Sem resposta. Se foi timeout, a operação pode ter completado no
        # servidor — não repita se ela não for idempotente.
        echo "  sem resposta — NÃO repetindo (pode ter completado)" >&2
        return 1
        ;;
      *)
        # Erro de negócio: repetir não muda nada.
        echo "  ${status} — erro de negócio, não repete: ${conteudo}" >&2
        return 1
        ;;
    esac
  done

  echo "  desisti depois de ${tentativas} tentativas" >&2
  return 1
}

echo
echo "→ GET /balance com retry"
com_retry /balance '{}' 3
rm -f /tmp/apibrasil-headers
