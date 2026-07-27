# Exemplos — SDK Node.js

SDK: [`apigratis-sdk-nodejs`](https://www.npmjs.com/package/apigratis-sdk-nodejs) ·
Repositório: <https://github.com/APIBrasil/apigratis-sdk-node>

Node >= 18 (usa `fetch` nativo). Zero dependências de runtime, ESM + CJS, tipos inclusos.
Roda também em Bun, Deno e Cloudflare Workers.

## Rodando

```bash
npm install
cp ../../.env-example ../../.env    # e preencha
node --env-file=../../.env 01-conta-e-saldo.mjs
```

`--env-file` é nativo do Node 20+. No Node 18, exporte as variáveis antes:

```bash
export APIBRASIL_BEARER_TOKEN=...
node 01-conta-e-saldo.mjs
```

| Arquivo | O que mostra |
| --- | --- |
| [01-conta-e-saldo.mjs](./01-conta-e-saldo.mjs) | cliente a partir do ambiente, status do gateway, saldo, plano |
| [02-consultas-por-credito.mjs](./02-consultas-por-credito.mjs) | CNPJ/CPF/veículos, campo `tipo`, homologação, envelope de cobrança |
| [03-whatsapp.mjs](./03-whatsapp.mjs) | device, sessão, QR Code, envio de texto e mídia, fila |
| [04-servicos-device.mjs](./04-servicos-device.mjs) | CEP, correios, placa, FIPE, clima, SMS |
| [05-erros-e-retry.mjs](./05-erros-e-retry.mjs) | erros tipados, política de retry, hooks |

## TypeScript

Os exemplos são `.mjs` para rodar sem build. Em TypeScript, a única diferença é o import —
o resto é idêntico, com autocomplete das actions e dos 210+ `tipo` de consulta:

```typescript
import { ApiBrasil, InsufficientBalanceError } from 'apigratis-sdk-nodejs';

const api = new ApiBrasil();
const socios = await api.consulta.cnpj({ cnpj: '00000000000000', tipo: 'lista-socios' });
//                                                                     ^ autocomplete do catálogo
```

Há também subpath exports para reduzir o bundle: `apigratis-sdk-nodejs/messaging`,
`/data`, `/platform`, `/core`.
