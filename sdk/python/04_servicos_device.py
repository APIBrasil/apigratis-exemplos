"""04 — Serviços device-based (fora do WhatsApp)

Todos seguem o mesmo formato: POST /{servico}/{action} com Bearer + DeviceToken.
O device precisa ser da API correspondente — um DeviceToken de WhatsApp dá 403
em /vehicles.

    python 04_servicos_device.py
"""

from __future__ import annotations

import datetime
import json
import os
from typing import Any, Callable

import env  # carrega o .env da raiz
from api_brasil import ApiBrasil, ApiBrasilError, NotFoundError

env.exigir("APIBRASIL_BEARER_TOKEN")

api = ApiBrasil()

# Cada API tem o seu device. Rode com o token certo por serviço, ou passe
# `device_token=...` na chamada — que é o que fazemos aqui.
PADRAO = os.environ.get("APIBRASIL_DEVICE_TOKEN")
devices = {
    "cep": os.environ.get("APIBRASIL_DEVICE_TOKEN_CEP", PADRAO),
    "correios": os.environ.get("APIBRASIL_DEVICE_TOKEN_CORREIOS", PADRAO),
    "veiculos": os.environ.get("APIBRASIL_DEVICE_TOKEN_VEICULOS", PADRAO),
    "clima": os.environ.get("APIBRASIL_DEVICE_TOKEN_CLIMA", PADRAO),
    "sms": os.environ.get("APIBRASIL_DEVICE_TOKEN_SMS", PADRAO),
}


def tentar(rotulo: str, fn: Callable[[], Any]) -> None:
    """Roda um bloco e reporta a falha sem derrubar os outros exemplos."""
    try:
        resposta = fn()
        corpo = resposta.get("response", resposta) if isinstance(resposta, dict) else resposta
        print(f"\n{rotulo}:")
        print(json.dumps(corpo, indent=2, ensure_ascii=False)[:600])
    except NotFoundError as erro:
        print(f"\n{rotulo}: sem dados (HTTP {erro.status})")
    except ApiBrasilError as erro:
        print(f"\n{rotulo}: {erro} (HTTP {erro.status})")


# CEP — endereço completo com geolocalização.
tentar("CEP", lambda: api.cep.cep({"cep": "01001000"}, device_token=devices["cep"]))

# Ainda em /cep: cidades por DDD, bairros, cidades, estados, distância.
tentar("Cidades por DDD", lambda: api.cep.request("cidadesPorDDD", {"ddd": "11"}, device_token=devices["cep"]))

# Correios — rastreio de encomenda.
tentar("Rastreio", lambda: api.correios.rastreio({"code": "AA123456789BR"}, device_token=devices["correios"]))

# Veículos por placa. Diferente de consulta.veiculos (créditos): aqui é device.
tentar("Placa · dados", lambda: api.vehicles.dados({"placa": "ABC1234"}, device_token=devices["veiculos"]))
tentar("Placa · FIPE", lambda: api.vehicles.fipe({"placa": "ABC1234"}, device_token=devices["veiculos"]))

# Tabela FIPE navegável: referência → marcas → modelos → ano → valor.
tentar(
    "FIPE · marcas",
    lambda: api.fipe.request(
        "ConsultarMarcas",
        {"codigoTabelaReferencia": 300, "codigoTipoVeiculo": 1},
        device_token=devices["veiculos"],
    ),
)

# Clima por cidade ou por coordenadas.
tentar("Clima", lambda: api.weather.request("city", {"city": "São Paulo"}, device_token=devices["clima"]))

# Feriados do ano (nacionais, estaduais, facultativos — o `type` decide).
tentar(
    "Feriados",
    lambda: api.holidays.request(
        "feriados",
        {"year": datetime.date.today().year},
        device_token=devices["clima"],
    ),
)

# GeoIP.
tentar("GeoIP", lambda: api.database_ip.ip({"ip": "8.8.8.8"}, device_token=devices["cep"]))

# SMS — device-based. Só envia de verdade com NUMERO definido.
numero = os.environ.get("NUMERO")
if numero:
    tentar(
        "SMS",
        lambda: api.sms.send({"number": numero, "message": "Seu código: 123456"}, device_token=devices["sms"]),
    )

    # Alternativa sem device, debitando créditos da conta:
    # api.sms.send_with_credits({"number": numero, "message": "Olá!"})

# Serviço sem método dedicado? A saída genérica cobre o gateway inteiro.
# api.request("POST", "/translate/text", {"text": "Olá", "to": "en"})
