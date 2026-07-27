"""Client MCP da APIBrasil — Python

Conecta no servidor MCP, lista as tools, faz chamadas e demonstra a descoberta
dinâmica.

    python client.py
"""

from __future__ import annotations

import asyncio
import json
import os
import sys
from collections import Counter
from pathlib import Path
from typing import Any

from mcp import ClientSession
from mcp.client.streamable_http import streamablehttp_client

# ---------------------------------------------------------------------------
# .env da raiz do repositório (sem depender de python-dotenv)
# ---------------------------------------------------------------------------
CAMINHO_ENV = Path(__file__).resolve().parents[2] / ".env"
if CAMINHO_ENV.is_file():
    for linha in CAMINHO_ENV.read_text(encoding="utf-8").splitlines():
        linha = linha.strip()
        if linha and not linha.startswith("#") and "=" in linha:
            chave, _, valor = linha.partition("=")
            chave, valor = chave.strip(), valor.strip().strip("\"'")
            if chave and valor and chave not in os.environ:
                os.environ[chave] = valor

MCP_URL = os.environ.get("APIBRASIL_MCP_URL", "https://mcp.apibrasil.cloud/mcp")
BEARER = os.environ.get("APIBRASIL_BEARER_TOKEN")
DEVICE_TOKEN = os.environ.get("APIBRASIL_DEVICE_TOKEN")

if not BEARER:
    print("Defina APIBRASIL_BEARER_TOKEN no .env da raiz.", file=sys.stderr)
    raise SystemExit(1)

# As credenciais vão por HEADER, não como argumento de tool: assim não entram no
# contexto do modelo nem nos logs de tool do client.
HEADERS = {"X-Apibrasil-Bearer": BEARER}
if DEVICE_TOKEN:
    HEADERS["DeviceToken"] = DEVICE_TOKEN
if os.environ.get("APIBRASIL_MCP_TOKEN"):
    # Autenticação do próprio servidor MCP (MCP_AUTH_TOKEN no deploy).
    HEADERS["Authorization"] = f"Bearer {os.environ['APIBRASIL_MCP_TOKEN']}"


def ler(resultado: Any) -> Any:
    """Extrai o dado útil de um resultado de tool.

    As tools da APIBrasil respondem com um bloco `text` contendo JSON e também
    com `structuredContent` — prefira o segundo.
    """
    estruturado = getattr(resultado, "structuredContent", None)
    if estruturado:
        return estruturado

    for bloco in getattr(resultado, "content", []) or []:
        texto = getattr(bloco, "text", None)
        if isinstance(texto, str):
            try:
                return json.loads(texto)
            except json.JSONDecodeError:
                return texto

    return resultado


async def chamar(sessao: ClientSession, nome: str, **argumentos: Any) -> Any:
    """Chama uma tool. Erro de negócio vem como resultado, não como exceção."""
    resultado = await sessao.call_tool(nome, argumentos)

    if getattr(resultado, "isError", False):
        # 402 saldo, 403 device/IP, 410 rota morta, 422 validação — o servidor
        # preserva a mensagem original do gateway.
        raise RuntimeError(f"{nome}: {ler(resultado)}")

    return ler(resultado)


async def main() -> None:
    # streamablehttp_client abre os streams; ClientSession monta a sessão MCP
    # em cima deles. Os dois ficam abertos enquanto a sessão é usada.
    async with streamablehttp_client(MCP_URL, headers=HEADERS) as (leitura, escrita, _):
        async with ClientSession(leitura, escrita) as sessao:
            await sessao.initialize()
            print(f"Conectado em {MCP_URL}")

            # ---------------------------------------------------------------
            # Tools disponíveis
            # ---------------------------------------------------------------
            # Profile `core` (padrão): ~23 tools + 3 de descoberta.
            # Profile `full`: ~223 — mais tools ocupam mais contexto do modelo.
            tools = (await sessao.list_tools()).tools
            print(f"\n{len(tools)} tool(s). Por domínio:")

            dominios = Counter(t.name.split(".")[1] if "." in t.name else "?" for t in tools)
            for dominio, total in sorted(dominios.items()):
                print(f"  apibrasil.{dominio}.* — {total}")

            # ---------------------------------------------------------------
            # Chamadas
            # ---------------------------------------------------------------
            # Nomes na convenção 2.0: apibrasil.<domínio>.<ação>.
            # O bearer já foi pelo header — não repita nos argumentos.
            print("\nSaldo:", await chamar(sessao, "apibrasil.balance.get"))

            # A sessão multiplexa: gather é bem mais rápido que sequencial.
            cep, clima = await asyncio.gather(
                chamar(sessao, "apibrasil.cep.lookup", cep="01001000"),
                chamar(sessao, "apibrasil.weather.city", city="São Paulo"),
            )
            print("\nCEP:", json.dumps(cep, ensure_ascii=False)[:300])
            print("\nClima:", json.dumps(clima, ensure_ascii=False)[:300])

            # Consulta por crédito. homolog=True roda em sandbox, sem debitar.
            cnpj = await chamar(
                sessao,
                "apibrasil.credits.consulta",
                service="cnpj",
                payload={"cnpj": "00000000000000", "homolog": True},
            )
            print("\nCNPJ (homologação):", json.dumps(cnpj, ensure_ascii=False)[:400])

            # WhatsApp exige DeviceToken — que também já foi pelo header.
            numero = os.environ.get("NUMERO")
            if DEVICE_TOKEN and numero:
                enviado = await chamar(
                    sessao,
                    "apibrasil.wpp.send_text",
                    number=numero,
                    text="Olá! Enviado via MCP 👋",
                )
                print("\nWhatsApp:", json.dumps(enviado, ensure_ascii=False)[:300])

            # ---------------------------------------------------------------
            # Descoberta dinâmica
            # ---------------------------------------------------------------
            # Três tools cobrem qualquer serviço do gateway, inclusive os sem
            # tool dedicada: catalog → describe → call. API nova aparece sem
            # redeploy do MCP.
            catalogo = await chamar(sessao, "apibrasil.discovery.catalog", search="cep")
            apis = catalogo.get("apis") if isinstance(catalogo, dict) else None
            print(f"\nDescoberta: {len(apis or [])} API(s) com \"cep\" no nome")

            if apis:
                servico = apis[0].get("service") or apis[0].get("slug")
                # describe traz o template do body — é o que evita o 422.
                template = await chamar(
                    sessao,
                    "apibrasil.discovery.describe",
                    service=servico,
                    action="cep",
                )
                print("Template do body:", json.dumps(template, ensure_ascii=False)[:400])

            # ---------------------------------------------------------------
            # Prompts e resources
            # ---------------------------------------------------------------
            # Resources (apibrasil://catalog) não ocupam espaço na lista de
            # tools — é o lugar certo para dados de referência.
            try:
                prompts = (await sessao.list_prompts()).prompts
                resources = (await sessao.list_resources()).resources
                print(f"\n{len(prompts)} prompt(s), {len(resources)} resource(s)")
            except Exception:
                pass


if __name__ == "__main__":
    asyncio.run(main())
