# Consulta CNPJ

Consulta o cadastro de um CNPJ, lista os sócios e exporta para CSV.

![](https://i.imgur.com/YCZRJsh.png)

## Rodando

```bash
cd ..                      # a partir de apps/
APIBRASIL_BEARER_TOKEN=... php -S localhost:8000
```

Abra <http://localhost:8000/consulta-cnpj/>.

Roda em **homologação** por padrão. Para dados reais (e debitar saldo), some
`APIBRASIL_HOMOLOG=0`.

## Arquivos

| Arquivo | O que é |
| --- | --- |
| [index.html](./index.html) | a tela, com exportação CSV no cliente |
| [backend.php](./backend.php) | o proxy: valida o CNPJ, adiciona o token, repassa |

## Um endpoint, vários produtos

`/consulta/cnpj/credits` é uma rota só. O que muda o produto — e o preço — é o
campo **`tipo`** no body:

| `tipo` | Devolve |
| --- | --- |
| *(ausente)* | cadastro básico: razão social, endereço, CNAE, situação |
| `lista-socios` | quadro societário |
| `serasa-score-pj` | score de crédito |
| `quod-cnpj` | birô Quod |

São 210+ tipos no catálogo. Para descobrir o que a sua conta pode consumir:
`GET /api/v2/apis`, e o template do body em `GET /api/v2/endpoint/body`.

Este app expõe os dois primeiros — a allowlist do `backend.php` controla quais.
Adicionar um tipo é uma linha; sem allowlist, o visitante escolheria qualquer
produto pago da sua conta.

## Sem DeviceToken

Consultas por crédito usam **só** o `Authorization`. O `DeviceToken` é ignorado
nessas rotas — é por isso que este app não precisa de device nenhum, diferente
do [consulta-placa](../consulta-placa/).
