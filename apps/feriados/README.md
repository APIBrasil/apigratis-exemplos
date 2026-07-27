# Feriados

Calendário do ano agrupado por mês, com contagem de feriados em dia útil e de
emendas possíveis.

## Rodando

```bash
cd ..                      # a partir de apps/
APIBRASIL_BEARER_TOKEN=... APIBRASIL_DEVICE_TOKEN_CLIMA=... php -S localhost:8000
```

Abra <http://localhost:8000/feriados/>.

## A action é em português

`POST /holidays/feriados` — o serviço tem nome em inglês e a action em
português. **Não existe `/holidays/holidays`.**

| Body | Devolve |
| --- | --- |
| `{ year, type: 'nacional' }` | feriados nacionais |
| `{ year, type: 'estadual', state: 'SP' }` | feriados de um estado |
| `{ year, type: 'facultativo' }` | pontos facultativos |

O campo `state` só é enviado quando `type` é `estadual` — o formulário esconde a
UF nos outros casos, e o [backend.php](./backend.php) só a inclui quando faz
sentido.

## Datas de dois formatos

O provedor pode devolver `2026-04-21` ou `21/04/2026`. A função `paraData()`
trata os dois e cai para o parser do `Date` como último recurso:

```javascript
const iso = texto.match(/^(\d{4})-(\d{2})-(\d{2})/);
const br  = texto.match(/^(\d{2})\/(\d{2})(?:\/(\d{4}))?/);
```

Cuidado com `new Date('2026-04-21')` puro: strings ISO **sem hora** são
interpretadas como UTC, e num fuso negativo a data volta um dia. Por isso o
código monta `new Date(ano, mes - 1, dia)`, que é sempre local.

## As contagens

Além de listar, o app calcula o que geralmente interessa de verdade:

- **em dia útil** — feriados que caem de segunda a sexta (os de fim de semana
  "não valem" para quem planeja escala)
- **emendas possíveis** — terça ou quinta, os dias que permitem emendar com o
  fim de semana

É o tipo de derivação que a API não faz e o app sim.

## Os 12 meses sempre aparecem

Mês sem feriado é renderizado esmaecido, com "sem feriados". Mostrar só os meses
com resultado esconde a informação de que aquele mês está vazio — e é isso que
alguém montando escala precisa ver.
