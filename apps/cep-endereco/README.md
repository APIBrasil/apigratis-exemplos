# CEP e endereço

Autocompletar de formulário por CEP, navegação UF → cidade → bairro, e cidades
por DDD.

## Rodando

```bash
cd ..                      # a partir de apps/
APIBRASIL_BEARER_TOKEN=... APIBRASIL_DEVICE_TOKEN_CEP=... php -S localhost:8000
```

Abra <http://localhost:8000/cep-endereco/>. Sem `_CEP`, o app cai para
`APIBRASIL_DEVICE_TOKEN`.

## O padrão de checkout

Este é o uso mais comum de API de CEP: o usuário digita 8 dígitos e os outros
seis campos se preenchem. Dois detalhes de implementação que importam:

**`change`/`blur`, não `input`.** Disparar a busca a cada tecla gera 8 chamadas
para um CEP — e cada uma conta no seu plano. O evento certo é quando o usuário
*termina* de digitar.

**Campos com nomes variáveis.** O provedor por trás do gateway pode devolver
`logradouro` ou `street`, `cidade` ou `localidade`. O helper `pegar()` no front
tenta as variantes em ordem, em vez de assumir uma.

## Cinco actions do mesmo serviço

`/cep/{action}` — todas device-based, todas no mesmo device:

| Action | Body | Para |
| --- | --- | --- |
| `cep` | `{ cep }` | endereço completo + geolocalização |
| `estados` | `{}` | lista de UFs |
| `cidades` | `{ uf }` | cidades de uma UF |
| `bairros` | `{ uf, cidade }` | bairros de uma cidade |
| `cidadesPorDDD` | `{ ddd }` | cidades atendidas por um DDD |
| `distancia/calcular` | dois CEPs | km entre eles — veja [distancia-cep](../distancia-cep/) |

## Allowlist de UF

O [backend.php](./backend.php) valida a UF contra a lista dos 27 estados. Parece
exagero para um select, mas o front é só sugestão: quem chama o seu endpoint
manda o que quiser. Validar no servidor é o que evita virar proxy aberto.

Repare também que a constante `UFS` é declarada **antes** de `Proxy::despachar()`
— ele não retorna, então nada depois dele executa.

## Degradação

Se o device de CEP não estiver configurado, a cascata UF → cidade → bairro fica
como "indisponível" e o resto do app continua funcionando. Um app que quebra
inteiro por causa de um recurso ausente é pior que um app parcial.
