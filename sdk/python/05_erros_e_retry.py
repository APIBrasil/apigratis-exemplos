"""05 — Erros, retry e observabilidade

A parte que separa um script de uma integração de produção.

    python 05_erros_e_retry.py
"""

from __future__ import annotations

import time
from typing import Any, Callable

import env  # carrega o .env da raiz
from api_brasil import (
    ApiBrasil,
    ApiBrasilError,
    ApiBrasilPermissionError,
    ApiBrasilTimeoutError,
    AuthenticationError,
    InsufficientBalanceError,
    NetworkError,
    NotFoundError,
    RateLimitError,
    ServerError,
    ValidationError,
)

# Nota: a SDK exporta PermissionError e TimeoutError com esses nomes, mas eles
# sombreiam builtins do Python. Use os aliases ApiBrasilPermissionError e
# ApiBrasilTimeoutError — são as mesmas classes.

env.exigir("APIBRASIL_BEARER_TOKEN")

# ---------------------------------------------------------------------------
# Retry
# ---------------------------------------------------------------------------
# O padrão são 2 tentativas extras, backoff exponencial, SÓ em 429 e falha de
# conexão — e respeitando o Retry-After da resposta.
#
# Timeout e erro de negócio nunca são repetidos: um send_text que deu timeout
# pode ter sido entregue, e uma consulta repetida cobra duas vezes.
api = ApiBrasil(
    timeout=30_000,  # milissegundos
    retry={
        "retries": 3,
        "min_delay_ms": 500,
        "retry_on_statuses": [429, 503],
    },
    # Hooks: é aqui que você pluga log estruturado, métricas ou tracing.
    hooks={
        "on_request": lambda i: print(f"→ {i['method']} {i['url']} (tentativa {i['attempt']})"),
        "on_response": lambda i: print(f"← {i['status']} em {i['duration_ms']}ms"),
        "on_retry": lambda i: print(f"↻ retry em {i['delay_ms']}ms: {i['reason']}"),
    },
)

# Para desligar: retry=False.

# ---------------------------------------------------------------------------
# Erros
# ---------------------------------------------------------------------------
# Cada status HTTP do gateway vira uma classe. Todas estendem ApiBrasilError e
# carregam .status, .code, .message e .response (o corpo original do gateway).
try:
    api.consulta.cpf({"cpf": "00000000000"})

except ValidationError as erro:
    # 400/422 — o body está errado. O template certo vem de
    # GET /api/v2/endpoint/body, e a doc está em doc.apibrasil.io.
    print("Payload inválido:", erro, erro.response)
except AuthenticationError:
    # 401 — bearer ausente/expirado. Refaça o login; não faça retry cego.
    print("Refaça o login.")
except InsufficientBalanceError as erro:
    # 402 — a mensagem já traz o valor exato da consulta que faltou.
    print("Recarregue:", erro)
except ApiBrasilPermissionError as erro:
    # 403 — DeviceToken de outra API, IP fora da whitelist, ou API que exige
    # cadastro PJ. São três causas com o mesmo status: leia a mensagem.
    print("Sem permissão:", erro)
except NotFoundError as erro:
    # 404 = não achou o dado. 410 = rota desativada, e a mensagem aponta a nova.
    print("Rota descontinuada:" if erro.status == 410 else "Sem dados:", erro)
except RateLimitError as erro:
    # 429 — a SDK já tentou de novo antes de chegar aqui.
    print(f"Limite atingido. Aguarde {erro.retry_after_ms}ms.")
except ServerError as erro:
    # 5xx — gateway ou provedor upstream. Repetir com backoff faz sentido.
    print(f"Falha do servidor: {erro.status} {erro}")
except ApiBrasilTimeoutError:
    # Estourou o tempo. ATENÇÃO: a operação pode ter completado no servidor.
    # Em envios e consultas, confirme o estado antes de repetir.
    print("Timeout — verifique o estado antes de tentar de novo.")
except NetworkError as erro:
    # Não chegou a haver resposta: DNS, TLS, conexão recusada.
    print("Falha de rede:", erro)
except ApiBrasilError as erro:
    print(f"Erro da SDK (HTTP {erro.status}, código {erro.code}): {erro}")


# ---------------------------------------------------------------------------
# Idempotência na prática
# ---------------------------------------------------------------------------
# Operações que cobram ou enviam merecem cuidado extra. O padrão abaixo repete
# só o que é seguro repetir.
def com_retry_seguro(fn: Callable[[], Any], tentativas: int = 3) -> Any:
    for i in range(1, tentativas + 1):
        try:
            return fn()
        except ApiBrasilTimeoutError:
            # ApiBrasilTimeoutError estende NetworkError, mas indica trabalho
            # possivelmente concluído — não repita operação não idempotente.
            raise
        except (ServerError, NetworkError):
            if i == tentativas:
                raise
            time.sleep(2**i * 0.25)


try:
    print("\nSaldo:", com_retry_seguro(api.account.balance))
except ApiBrasilError as erro:
    print("Desisti:", erro)
