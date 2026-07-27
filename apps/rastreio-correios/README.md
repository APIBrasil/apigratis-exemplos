# Rastreio de encomendas

Histórico dos Correios em linha do tempo, com escolha entre cobrança por device
ou por crédito.

## Rodando

```bash
cd ..                      # a partir de apps/
APIBRASIL_BEARER_TOKEN=... APIBRASIL_DEVICE_TOKEN_CORREIOS=... php -S localhost:8000
```

Abra <http://localhost:8000/rastreio-correios/>.

Sem device de Correios, use a opção **Crédito** no select — ela não precisa de
device nenhum.

## A mesma informação, duas cobranças

| Rota | Autenticação | Cobrança |
| --- | --- | --- |
| `POST /correios/rastreio` | Bearer + **DeviceToken** | por device/plano |
| `POST /consulta/rastreio/credits` | Bearer | debita saldo |

Esse par existe em vários serviços da plataforma (veículos é outro caso). Vale
saber qual das duas o seu plano cobre — dá para ter as duas na mesma conta.

O select do app troca entre elas e nada mais muda no front, porque as duas
devolvem o mesmo conteúdo dentro de envelopes diferentes (`response` vs `data`).
O helper `conteudo()` de [`_comum/app.js`](../_comum/app.js) abstrai isso.

## Formato do código

`AA123456789BR` — duas letras, nove dígitos, duas letras. O
[backend.php](./backend.php) valida antes de chamar: um código digitado errado
que passasse viraria uma consulta cobrada com resultado vazio.

## Campos que variam

A estrutura do histórico muda conforme o provedor por trás do gateway. Alguns
devolvem `eventos`, outros `events`, `historico` ou `objetos[0].evento`; a data
pode vir em `data` + `hora` separados ou num `dtHrCriado` ISO.

O front tenta as variantes conhecidas em ordem, em vez de assumir uma — é o que
faz o app sobreviver a uma troca de provedor. Para ver o formato que a sua conta
recebe, abra "Resposta completa do gateway" no fim da página.

## Sem movimentações não é erro

Objeto recém-postado costuma levar horas para aparecer no rastreio. A resposta
vem 200 com a lista vazia, e o app mostra um aviso em vez de erro — não confunda
com 404, que é código inexistente.
