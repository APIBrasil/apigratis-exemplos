# Distância entre CEPs

Quilometragem entre origem e destino, com simulação de frete em cima do
resultado.

## Rodando

```bash
cd ..                      # a partir de apps/
APIBRASIL_BEARER_TOKEN=... APIBRASIL_DEVICE_TOKEN_CEP=... php -S localhost:8000
```

Abra <http://localhost:8000/distancia-cep/>.

## Distância rodoviária, não linha reta

O número devolvido é o de rota, que é o que serve para frete. Distância
geodésica (linha reta) subestima em 20–40% no Brasil por causa do traçado das
estradas — se você está calculando preço com Haversine, está cobrando menos do
que deveria.

## O cálculo de frete é seu

A API entrega a distância. A tabela de preço é regra de negócio — não existe
endpoint para ela. Este app mostra a divisão de responsabilidade:

```
taxa fixa + (km × valor por km) + (peso × valor por kg)
```

A simulação roda **no navegador** e recalcula a cada tecla, sem nova chamada.
É o padrão certo: a consulta cobrada acontece uma vez; ajustar parâmetros de
preço não deve custar nada.

Para frete regulado (ANTT), a plataforma tem um produto próprio —
`/consulta/frete-antt/credits`.

## Números em formato brasileiro

O provedor pode devolver `"1.234,5 km"`, `"1234.5"` ou `1234.5`. A função
`paraNumero()` normaliza os três:

```javascript
String(valor)
    .replace(/[^\d,.-]/g, '')        // tira "km", espaços
    .replace(/\.(?=\d{3}\b)/g, '')   // tira separador de milhar
    .replace(',', '.')               // vírgula decimal → ponto
```

A ordem importa: remover o milhar **antes** de trocar a vírgula, senão
`1.234,5` vira `1.234.5` e o `Number()` devolve `NaN`.

## Endereço é enfeite

Os dois cartões com o endereço de cada ponta vêm de chamadas extras a
`/cep/cep`, feitas **depois** do resultado principal e com `try/catch` que
engole a falha. Se o device de CEP não estiver configurado, o app mostra a
distância e deixa o endereço como `—` — em vez de quebrar inteiro por causa de
um detalhe visual.

## Origem igual ao destino

Checado no front antes de chamar: a resposta seria zero e a consulta seria
cobrada igual. É o tipo de validação que se paga.
