"""01 — Conta e saldo

O básico: montar o cliente, confirmar que o gateway responde e ler os dados da
conta. Nada aqui gasta crédito.

    python 01_conta_e_saldo.py
"""

from __future__ import annotations

import env  # carrega o .env da raiz  # noqa: F401
from api_brasil import ApiBrasil, ApiBrasilError, AuthenticationError

# Sem argumentos, o cliente lê APIBRASIL_BEARER_TOKEN, APIBRASIL_DEVICE_TOKEN,
# APIBRASIL_SECRET_KEY e APIBRASIL_BASE_URL do ambiente.
api = ApiBrasil()

# /status é público — separa "minha credencial está errada" de "o gateway caiu".
status = api.catalog.status()
print("Gateway:", status.get("message", status))

env.exigir("APIBRASIL_BEARER_TOKEN")

try:
    print("Saldo:", api.account.balance())
    print("Plano:", api.account.plan())

    # Devices ativos na conta — cada um é uma instância de um serviço.
    devices = api.devices.list().get("devices", [])
    print(f"\n{len(devices)} device(s):")
    for device in devices:
        nome = device.get("device_name", "—")
        servico = (device.get("api") or {}).get("name", "—")
        print(f"  {nome} · {servico} · {device.get('status', '—')}")

except AuthenticationError:
    raise SystemExit("Bearer inválido ou expirado — refaça o login no painel.")
except ApiBrasilError as erro:
    raise SystemExit(f"Falhou (HTTP {erro.status}): {erro}")

# Login por email/senha, se você preferir não guardar o JWT:
#
#   api = ApiBrasil()
#   sessao = api.auth.login({"email": email, "password": senha})
#   if sessao.get("requires_2fa"):
#       api.auth.send_2fa({"challenge": sessao["challenge"], "method": "email"})
#       api.auth.verify_2fa({"challenge": sessao["challenge"], "code": "000000"})
#   # o token já ficou guardado no cliente — siga usando `api` normalmente
