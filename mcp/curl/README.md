# MCP na mão, com curl

Útil para depurar: se a sessão MCP funciona no curl e não funciona no seu
client, o problema é no client.

O Streamable HTTP é JSON-RPC 2.0 sobre POST, com uma sessão identificada pelo
header `Mcp-Session-Id`. O fluxo é sempre:

```
1. initialize          → a resposta traz o header Mcp-Session-Id
2. notifications/initialized
3. tools/list, tools/call, prompts/list, resources/list  (com o Mcp-Session-Id)
```

## Rodando

```bash
export APIBRASIL_BEARER_TOKEN=...
export APIBRASIL_DEVICE_TOKEN=...     # opcional
bash sessao.sh
```

Contra um servidor local (`npm run dev` no repo do MCP server):

```bash
APIBRASIL_MCP_URL=http://localhost:3030/mcp bash sessao.sh
```

## Os arquivos

| Arquivo | O que é |
| --- | --- |
| [sessao.sh](./sessao.sh) | o fluxo completo: initialize → tools/list → tools/call |
| [requisicoes/](./requisicoes/) | corpos JSON-RPC prontos para `curl -d @arquivo.json` |

## Detalhes que costumam morder

**`Accept` precisa dos dois tipos.** O Streamable HTTP pode responder JSON ou
abrir um stream SSE: mande `Accept: application/json, text/event-stream`. Sem o
`text/event-stream`, alguns servidores recusam.

**O `Mcp-Session-Id` vem no header, não no corpo.** É por isso que o
`initialize` usa `curl -i` (ou `-D -`) — para você conseguir lê-lo.

**A resposta do `initialize` pode vir como SSE.** Nesse caso o corpo é
`event: message\ndata: {...}` — extraia o JSON da linha `data:`.

**Credenciais por header.** `X-Apibrasil-Bearer`, `DeviceToken`, `SecretKey`.
Se o deploy do MCP exigir autenticação própria, some um
`Authorization: Bearer <MCP_AUTH_TOKEN>` (ou `X-MCP-Token`) — não confunda com
o bearer da APIBrasil.

**Health check.** `GET /health` no servidor MCP responde sem sessão nem
autenticação — use para monitoração.
