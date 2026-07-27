# MCP — APIBrasil para agentes de IA

O **Model Context Protocol** deixa um modelo (Claude, Cursor, VS Code, n8n…)
descobrir e chamar as APIs da APIBrasil sozinho, sem você escrever integração
para cada endpoint.

| | |
| --- | --- |
| **Servidor MCP** | `https://mcp.apibrasil.cloud/mcp` (Streamable HTTP) |
| **Pacote npm** | `apibrasil-mcp-server` — roda local via `npx -y apibrasil-mcp-server stdio` |
| **Repositório** | <https://github.com/APIBrasil/apibrasil-mcp-server> |
| **Base de conhecimento** | <https://github.com/APIBrasil/apibrasil-mcp-client> |

## MCP ou REST?

| | MCP | REST (SDK ou HTTP) |
| --- | --- | --- |
| Protocolo | Streamable HTTP com sessão | HTTP request/response |
| Estado | **stateful** — sessão persistente | **stateless** |
| Ideal para | Claude, Cursor, VS Code, agentes de IA | n8n, Typebot, webhooks, backend próprio |
| Vantagem | o modelo descobre as APIs e escolhe sozinho | simplicidade e compatibilidade universal |

Se você está escrevendo código que já sabe qual endpoint chamar, use
[sdk/](../sdk/). MCP é para quando **o modelo** decide.

## Conteúdo

| Pasta | O que tem |
| --- | --- |
| [configs/](./configs/) | JSONs prontos para Claude Desktop, Cursor, VS Code e a ponte `mcp-remote` |
| [nodejs/](./nodejs/) | client MCP em Node: conectar, listar tools, chamar, e o fluxo de descoberta |
| [python/](./python/) | o mesmo em Python, com o SDK oficial `mcp` |
| [curl/](./curl/) | o protocolo na mão: `initialize` → `Mcp-Session-Id` → `tools/call` |

## As três formas de passar credencial

Esta é a decisão mais importante ao integrar. Em ordem de preferência:

1. **Header da requisição MCP** — `X-Apibrasil-Bearer`, `DeviceToken`, `SecretKey`.
   O token **não passa pelo contexto do modelo** nem pelos logs de tool do client.
   É o que os exemplos daqui usam.
2. **Ambiente** (modo stdio) — `APIBRASIL_BEARER`, `APIBRASIL_DEVICE_TOKEN`,
   `APIBRASIL_SECRET_KEY`. Injetados automaticamente nas chamadas.
3. **Argumento de tool** — `bearer`, `deviceToken`, `SecretKey` no `arguments`.
   Funciona, mas o token vira texto no contexto do modelo. Evite.

Argumento explícito sempre vence o header.

## Nomes de tools: a mudança da 2.0

Se você tem código da versão 1.x, ele **quebrou**. Todo nome publicado agora tem
exatamente três segmentos — `apibrasil.<domínio>.<ação>`:

| 1.x | 2.0 |
| --- | --- |
| `apibrasil_call` | `apibrasil.discovery.call` |
| `auth_login` | `apibrasil.auth.login` |
| `cep_lookup` | `apibrasil.cep.lookup` |
| `wpp_sendText` | `apibrasil.wpp.send_text` |
| `plan_get` | `apibrasil.account.plan_get` |

Ações compostas viram um segmento com underscore
(`apibrasil.account.ip_whitelist_current_ip`) — nunca um quarto nível.

Para migrar sem reescrever tudo de uma vez, `APIBRASIL_LEGACY_TOOL_NAMES=1` no
servidor registra também os nomes antigos como alias. Fica desligado por padrão
porque publicar os dois nomes dobra a lista de tools no contexto do modelo.

**Nome com ponto e function calling estilo OpenAI:** a spec do MCP não restringe
os caracteres do `name`, mas essa ponte não aceita ponto. Se o seu client
repassa o nome para lá, ligue os nomes legados.

## Descoberta dinâmica

O gateway roteia por catch-all e expõe o catálogo vivo. Em vez de uma tool por
endpoint, três tools cobrem **qualquer** serviço — inclusive os que ainda não
têm tool dedicada:

| Tool | Faz | Rota do gateway |
| --- | --- | --- |
| `apibrasil.discovery.catalog` | lista as APIs ativas (slug, serviço, preço) | `GET /api/v2/apis` |
| `apibrasil.discovery.describe` | template do body de uma action | `GET /api/v2/endpoint/body` |
| `apibrasil.discovery.call` | despacha `service`/`action`/`payload` | `ANY /api/v2/{service}/{action}` |

Fluxo típico: **catalog → describe → call**. API nova no gateway aparece sem
redeploy do MCP. Veja [nodejs/descoberta.mjs](./nodejs/descoberta.mjs).

## Profiles

`APIBRASIL_TOOLS_PROFILE` controla quantas tools são registradas:

- **`core`** (padrão) — ~23 tools dos fluxos diretos + as 3 de descoberta.
  Cabe folgado na lista de tools de qualquer client.
- **`full`** — catálogo tipado completo (~223 tools).

Mais tools não é melhor: cada uma ocupa espaço no contexto do modelo. Comece no
`core` e use a descoberta para o resto.

## Annotations e cobrança

Toda tool declara `annotations` MCP para o client decidir auto-aprovação:
consultas puras são `readOnlyHint`; envios, exclusões, recargas e ligações são
`destructiveHint`.

**Consultas tarifadas não são marcadas `readOnly`** — debitar crédito é efeito
colateral, e auto-aprovar isso gastaria saldo sem você ver. Se o seu client
auto-aprova `readOnlyHint`, ele não vai gastar seu saldo sozinho.

## Erros

O servidor preserva o status semântico do gateway em vez de devolver
`HTTP 402` opaco: o resultado vem com `isError`, a mensagem original e uma dica
acionável. 402 é saldo, 403 é device/IP, 410 é rota morta, 422 é validação —
igual à tabela do [README raiz](../README.md#erros-que-valem-conhecer).
