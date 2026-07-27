# Client MCP — Node.js

SDK oficial do MCP: [`@modelcontextprotocol/sdk`](https://www.npmjs.com/package/@modelcontextprotocol/sdk).

## Rodando

```bash
npm install
cp ../../.env-example ../../.env    # e preencha
npm start          # app.mjs      — conectar, listar, chamar
npm run descoberta # descoberta.mjs — catalog → describe → call
```

| Arquivo | O que mostra |
| --- | --- |
| [app.mjs](./app.mjs) | conexão Streamable HTTP, credenciais por header, `tools/list`, chamadas em paralelo, leitura do resultado |
| [descoberta.mjs](./descoberta.mjs) | as 3 tools de descoberta: achar a API, pegar o template do body, chamar |

## O que mudou em relação ao exemplo antigo

Se você tem código de antes, três coisas quebraram:

| Antes (1.x) | Agora (2.0) |
| --- | --- |
| `SSEClientTransport` | `StreamableHTTPClientTransport` |
| `apibrasil.cep_lookup` | `apibrasil.cep.lookup` |
| token como argumento de tool | token por header (`X-Apibrasil-Bearer`) |

O SSE foi descontinuado no MCP em favor do Streamable HTTP — que é stateful de
verdade, com `Mcp-Session-Id` e reconexão.

## Lendo o resultado de uma tool

O MCP devolve `content[]` com blocos tipados. As tools da APIBrasil respondem
com um bloco `text` contendo JSON, **e também** `structuredContent` (via
`outputSchema`). Prefira o `structuredContent` quando existir — é o mesmo dado,
já parseado:

```javascript
const resultado = await client.callTool({ name: '...', arguments: {} });

const dados = resultado.structuredContent
  ?? JSON.parse(resultado.content.find((c) => c.type === 'text')?.text ?? 'null');
```

E confira `resultado.isError` antes de usar: erro de negócio do gateway (402,
403, 422) vem como resultado com `isError: true`, não como exceção.
