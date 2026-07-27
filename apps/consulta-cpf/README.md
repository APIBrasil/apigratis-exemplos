# Consulta CPF

Dados cadastrais e score de crédito, com os produtos de birô num só endpoint.

## Rodando

```bash
cd ..                      # a partir de apps/
APIBRASIL_BEARER_TOKEN=... php -S localhost:8000
```

Abra <http://localhost:8000/consulta-cpf/>. Homologação por padrão; para valer,
`APIBRASIL_HOMOLOG=0`.

## Um endpoint, cinco produtos

`/consulta/cpf/credits` é uma rota só. O campo **`tipo`** decide o produto — e o
preço:

| `tipo` | Devolve |
| --- | --- |
| *(ausente)* | dados cadastrais: nome, nascimento, situação na Receita |
| `serasa-score-pf` | score de crédito |
| `serasa-premium-pf` | relatório Serasa completo |
| `spc-serasa` | débitos SPC + Serasa |
| `cred-plus-cpf` | Cred Plus |

A allowlist do [backend.php](./backend.php) controla quais estão expostos.
Adicionar um é uma linha — sem allowlist, o visitante escolheria qualquer
produto pago da sua conta.

## 403 aqui costuma ser cadastro, não código

A consulta de CPF exige **cadastro prévio** na plataforma, e vários produtos
exigem **conta PJ**. O gateway usa 403 para os três casos:

- `DeviceToken` de outra API (não se aplica aqui — esta rota não usa device)
- IP fora da whitelist da conta
- API marcada como `pj_is_required` sendo consumida por conta PF

A mensagem do gateway diz qual é. Antes de debugar o código, confira o cadastro
no painel.

## Data de nascimento

Alguns birôs exigem `datanascimento` junto do CPF. O campo é opcional no
formulário e só vai ao gateway quando preenchido — se o produto exigir e ele
faltar, a resposta é 422 com a lista de campos.

## Rota antiga

`/debitos/cpf/credits` foi **desativada** (410). A substituta é
`/consulta/cpf/credits` com `tipo: spc-serasa` — que é o que este app usa na
opção "SPC + Serasa".
