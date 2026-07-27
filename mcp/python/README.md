# Client MCP — Python

SDK oficial do MCP: [`mcp`](https://pypi.org/project/mcp/).

## Rodando

```bash
python -m venv .venv && . .venv/bin/activate    # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp ../../.env-example ../../.env                # e preencha
python client.py
```

| Arquivo | O que mostra |
| --- | --- |
| [client.py](./client.py) | conexão Streamable HTTP, credenciais por header, `list_tools`, chamadas concorrentes, descoberta dinâmica |

## Detalhes do SDK Python

**Tudo é async.** `streamablehttp_client` é um async context manager que devolve
os streams de leitura/escrita; a `ClientSession` monta a sessão MCP em cima
deles. Os dois precisam ficar abertos enquanto você usa a sessão — por isso o
`async with` aninhado.

**Chamadas concorrentes.** A sessão multiplexa: `asyncio.gather` sobre vários
`call_tool` funciona e é bem mais rápido que sequencial.

**Resultado.** `result.structuredContent` quando existir; senão, o JSON dentro
do bloco `text` de `result.content`. E confira `result.isError` — erro de
negócio do gateway (402, 403, 422) vem como resultado, não como exceção.
