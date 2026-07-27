"""03 — WhatsApp

Serviço device-based: exige Authorization: Bearer + header DeviceToken.
O DeviceToken identifica UMA sessão de WhatsApp; o bearer identifica a conta.

Fluxo completo: device → sessão → QR Code → pareamento → envio.

    python 03_whatsapp.py                          # usa o device do .env
    CRIAR_DEVICE=1 python 03_whatsapp.py           # cria um device novo
    NUMERO=5511999999999 python 03_whatsapp.py     # e envia de verdade
"""

from __future__ import annotations

import base64
import os
from pathlib import Path

import env  # carrega o .env da raiz
from api_brasil import ApiBrasil, ApiBrasilPermissionError

env.exigir("APIBRASIL_BEARER_TOKEN")

api = ApiBrasil()
tem_device = bool(os.environ.get("APIBRASIL_DEVICE_TOKEN"))

# ---------------------------------------------------------------------------
# 1. O device
# ---------------------------------------------------------------------------
# A SecretKey (painel → API WhatsApp → SecretKey) é a única credencial que cria
# devices. Depois de criado, o device_token substitui ela no dia a dia.
if os.environ.get("CRIAR_DEVICE") == "1":
    secret_key = env.exigir("APIBRASIL_SECRET_KEY", "CRIAR_DEVICE=1 precisa dela para criar o device.")

    criado = api.devices.store(
        {"device_name": "exemplo-python", "type": "server"},
        secret_key=secret_key,
    )

    token = (criado.get("device") or {}).get("device_token")
    print("Device criado. Guarde este token no seu .env:")
    print(f"APIBRASIL_DEVICE_TOKEN={token}\n")

    api.set_device_token(token)
    tem_device = True

if not tem_device:
    raise SystemExit("Defina APIBRASIL_DEVICE_TOKEN no .env, ou rode com CRIAR_DEVICE=1.")

# ---------------------------------------------------------------------------
# 2. A sessão
# ---------------------------------------------------------------------------
# Os webhooks são opcionais, mas é aqui que se registram — não existe outra
# chamada para isso. Sem eles você só descobre mensagens recebidas por polling.
webhooks = {
    "webhook_wh_message": os.environ.get("WEBHOOK_MENSAGENS"),  # mensagem recebida
    "webhook_wh_status": os.environ.get("WEBHOOK_STATUS"),      # status da sessão mudou
    "webhook_wh_connect": os.environ.get("WEBHOOK_CONEXAO"),    # conectou/desconectou
    "webhook_wh_qrcode": os.environ.get("WEBHOOK_QRCODE"),      # novo QR Code gerado
}

try:
    sessao = api.whatsapp.start({k: v for k, v in webhooks.items() if v})
    print("Sessão:", sessao.get("message", sessao))
except ApiBrasilPermissionError as erro:
    # 403 aqui é quase sempre DeviceToken de outra API, ou IP fora da whitelist.
    raise SystemExit(f"Sem permissão para esse device: {erro}")

# ---------------------------------------------------------------------------
# 3. O QR Code
# ---------------------------------------------------------------------------
# Vem como data URI base64. Numa aplicação real você joga isso num <img src>;
# aqui gravamos em disco para escanear.
qr = api.whatsapp.qrcode()
resposta_qr = qr.get("response")
data_uri = resposta_qr.get("qrcode") if isinstance(resposta_qr, dict) else None

if isinstance(data_uri, str) and data_uri.startswith("data:image"):
    Path("qrcode.png").write_bytes(base64.b64decode(data_uri.split(",", 1)[1]))
    print("QR Code salvo em qrcode.png — escaneie no WhatsApp → aparelhos conectados.")
else:
    print("QR Code:", qr.get("response") or qr.get("message") or "sessão provavelmente já conectada")

# ---------------------------------------------------------------------------
# 4. Envios
# ---------------------------------------------------------------------------
numero = os.environ.get("NUMERO")
if not numero:
    print("\nDefina NUMERO=5511999999999 para enviar de verdade.")
    raise SystemExit(0)

# Texto. `time_typing` simula "digitando..." antes de entregar.
texto = api.whatsapp.send_text(
    {
        "number": numero,
        "text": "Olá! Mensagem enviada pela SDK Python da APIBrasil 👋",
        "time_typing": 1500,
    }
)
print("Texto:", texto.get("message", texto))

# Arquivo por URL pública. Para base64, use send_file64.
api.whatsapp.send_file(
    {
        "number": numero,
        "path": "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf",
        "caption": "Segue o documento",
    }
)

# Áudio (o gateway converte para mp3; máx. 6 min) e localização.
api.whatsapp.send_audio({"number": numero, "path": "https://filesamples.com/samples/audio/mp3/sample3.mp3"})
api.whatsapp.send_location({"number": numero, "lat": -23.5613, "lng": -46.6565})

# Qualquer action da documentação, mesmo sem método dedicado na SDK.
api.whatsapp.request("sendLink", {"number": numero, "url": "https://apibrasil.com.br", "text": "Conheça"})

# Fila: mesma action, processada de forma assíncrona pelo gateway. É o caminho
# certo para disparos em volume — devolve na hora e não segura sua requisição.
enfileirado = api.whatsapp.queue("sendText", {"number": numero, "text": "Esta foi pela fila 🚀"})
print("Fila:", enfileirado.get("message", enfileirado))

# ---------------------------------------------------------------------------
# 5. Vários devices no mesmo processo
# ---------------------------------------------------------------------------
# with_device devolve um cliente novo, sem alterar o original.
suporte_token = os.environ.get("APIBRASIL_DEVICE_TOKEN_SUPORTE")
if suporte_token:
    suporte = api.with_device(suporte_token)
    suporte.whatsapp.send_text({"number": numero, "text": "Falando pela sessão do suporte"})
