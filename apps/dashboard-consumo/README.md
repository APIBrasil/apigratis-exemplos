# Dashboard de consumo

Saldo, plano, uso diário, erros e consumo por device — o painel que responde
"onde o meu saldo está indo".

## Rodando

```bash
cd ..                      # a partir de apps/
APIBRASIL_BEARER_TOKEN=... php -S localhost:8000
```

Abra <http://localhost:8000/dashboard-consumo/>.

Só precisa do bearer. **É o único app aqui que não gasta nada** — todas as rotas
são leitura de plataforma.

## As rotas

Todas `GET`, sem DeviceToken, sem cobrança por consulta:

| Rota | Devolve |
| --- | --- |
| `/balance` | saldo/créditos |
| `/plan` | plano atual |
| `/devices` | devices da conta |
| `/dashboard/stats` | números gerais |
| `/reports/quick-stats` | total de requisições e taxa de erro |
| `/reports/summary` | resumo do período |
| `/reports/daily-usage?days=30` | série diária |
| `/reports/error-analysis?days=30` | erros agrupados por status |
| `/reports/device-analysis?days=30` | consumo por device |
| `/reports/recent-requests?limit=20` | últimas chamadas |

O filtro vai na **query string** (`?days=30`), não no corpo — são rotas GET. O
proxy compartilhado suporta isso pelo campo `'query'` da ação, em vez de
`'corpo'`.

## Gráfico sem biblioteca

O uso diário é um `<ul>` com `display: grid; grid-auto-flow: column` e uma `<div>`
por barra, com `height` em porcentagem do pico. São ~20 linhas de CSS.

Puxar Chart.js (ou qualquer coisa via CDN) para desenhar 30 barras adiciona
~200 KB, uma dependência externa e um ponto de falha. Para gráfico de barras
simples, CSS resolve — se você precisar de eixos, tooltips ricos e zoom, aí sim
vale a biblioteca.

## `allSettled`, não `all`

São oito chamadas em paralelo, e **algumas dependem do plano da conta**. Com
`Promise.all`, uma rota indisponível derrubaria o dashboard inteiro. Com
`allSettled`, o que funciona aparece e o que faltou vai para um aviso no topo:

> Indisponível para esta conta: device-analysis, summary.

Isso é diferente de erro — é o dashboard dizendo o que o seu plano cobre.

## Campos aninhados

As rotas de relatório não têm formato uniforme: o saldo pode vir em `balance`,
`saldo`, `credits` ou aninhado sob `data`. A função `buscarFundo()` desce
recursivamente pelos objetos procurando a primeira chave conhecida:

```javascript
buscarFundo(resposta, 'total_requests', 'total', 'requests')
```

Menos elegante que um contrato fixo, mas é o que sobrevive a diferenças entre
planos e versões. O `<details>` no fim mostra tudo que veio, para você conferir o
formato da sua conta.
