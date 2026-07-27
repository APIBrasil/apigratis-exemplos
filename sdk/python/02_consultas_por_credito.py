"""02 — Consultas por crédito

Rotas /consulta/{servico}/credits. Só precisam do bearer: debitam o saldo da
conta e ignoram o DeviceToken.

Roda em HOMOLOGAÇÃO por padrão (dados fictícios, sem cobrança).
Para valer, rode com COBRAR=1.

    python 02_consultas_por_credito.py
    COBRAR=1 python 02_consultas_por_credito.py
"""

from __future__ import annotations

import json
import os

import env  # carrega o .env da raiz
from api_brasil import ApiBrasil, InsufficientBalanceError, ValidationError

env.exigir("APIBRASIL_BEARER_TOKEN")

api = ApiBrasil()

# `homolog: True` é o sandbox da plataforma — não existe URL separada de teste.
homolog = os.environ.get("COBRAR") != "1"
print("· modo homologação (sem cobrança)\n" if homolog else "· CONSULTAS REAIS — vai debitar saldo\n")


def resumir(rotulo: str, resposta: dict) -> None:
    """Toda consulta devolve o mesmo envelope: error, message, balance, valor_consulta, data."""
    print(f"{rotulo}:")
    print("  custou:", resposta.get("valor_consulta", "—"), "| saldo restante:", resposta.get("balance", "—"))
    print("  data:", json.dumps(resposta.get("data"), ensure_ascii=False)[:300])


try:
    # CNPJ — cadastro básico.
    resumir("CNPJ", api.consulta.cnpj({"cnpj": "00000000000000", "homolog": homolog}))

    # O campo `tipo` é o que escolhe o PRODUTO dentro do serviço. Mesmo endpoint,
    # preço e retorno diferentes. São 210+ tipos no catálogo.
    resumir(
        "CNPJ · lista-socios",
        api.consulta.cnpj({"cnpj": "00000000000000", "tipo": "lista-socios", "homolog": homolog}),
    )

    # CPF.
    resumir("CPF", api.consulta.cpf({"cpf": "00000000000", "homolog": homolog}))

    # Veicular por placa.
    resumir("Veículos", api.consulta.veiculos({"placa": "ABC1234", "homolog": homolog}))

    # Qualquer serviço do catálogo, inclusive os sem método dedicado.
    resumir(
        "Serasa Score PF",
        api.consulta.generic("cpf", {"cpf": "00000000000", "tipo": "serasa-score-pf", "homolog": homolog}),
    )

    # Descobrindo o que existe: catálogo vivo do gateway.
    apis = api.catalog.apis("consulta").get("apis", [])
    print(f'\n{len(apis)} API(s) com "consulta" no nome. Primeiras:')
    for item in apis[:5]:
        print(f"  {item.get('name', '—')} · R$ {item.get('price', '—')}")

except InsufficientBalanceError as erro:
    # 402 — a mensagem do gateway já traz o valor exato da consulta.
    raise SystemExit(f"Sem saldo: {erro}")
except ValidationError as erro:
    # 422 — o template do body está em GET /api/v2/endpoint/body.
    raise SystemExit(f"Body inválido: {erro} — {erro.response}")
