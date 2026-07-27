# Tabela FIPE

Navegação em cascata até o preço médio: referência → tipo → marca → modelo →
ano → valor.

## Rodando

```bash
cd ..                      # a partir de apps/
APIBRASIL_BEARER_TOKEN=... APIBRASIL_DEVICE_TOKEN_VEICULOS=... php -S localhost:8000
```

Abra <http://localhost:8000/fipe-tabela/>.

## O case das actions importa

As actions da FIPE são **PascalCase**:

| Correto | Errado |
| --- | --- |
| `ConsultarTabelaDeReferencia` | `consultarTabelaDeReferencia` |
| `ConsultarMarcas` | `consultarMarcas` |
| `ConsultarModelos` | `consultarModelos` |
| `ConsultarAnoModelo` | `consultarAnoModelo` |
| `ConsultarValorComTodosParametros` | `consultarValorComTodosParametros` |

O gateway monta a URL do provedor com `$endpoint . '/' . $action` — a action vai
**verbatim**. Com o case errado, o erro vem do provedor lá em cima, não do
gateway, e a mensagem não deixa óbvio que o problema era uma letra maiúscula.

## A cascata, passo a passo

Cada nível precisa dos códigos de todos os anteriores:

```
ConsultarTabelaDeReferencia   {}
ConsultarMarcas               { codigoTabelaReferencia, codigoTipoVeiculo }
ConsultarModelos              { ... + codigoMarca }
ConsultarAnoModelo            { ... + codigoModelo }
ConsultarValorComTodosParametros
                              { ... + anoModelo, codigoTipoCombustivel, tipoConsulta }
```

`codigoTipoVeiculo`: **1** carro, **2** moto, **3** caminhão.

## O detalhe que trava todo mundo

`ConsultarAnoModelo` devolve o código do ano no formato **`"2015-1"`** — ano e
tipo de combustível colados. A action final espera os dois **separados**:

```javascript
const [ano, combustivel] = String(selAno.value).split('-');
// → anoModelo: 2015, codigoTipoCombustivel: 1
```

Mandar `"2015-1"` em `anoModelo` resulta em erro de validação no provedor.

## Chaves com maiúscula

Diferente do resto da plataforma, a FIPE devolve chaves em PascalCase:
`Valor`, `Marca`, `Modelo`, `AnoModelo`, `Combustivel`, `CodigoFipe`,
`MesReferencia`. O front tenta as variantes minúsculas também, mas é o PascalCase
que costuma chegar.

## Limpando os níveis abaixo

Quando a marca muda, modelo e ano precisam ser zerados — senão o usuário
consegue submeter uma combinação impossível (modelo de uma marca com o código de
outra) e recebe um 422 confuso. A função `limparAbaixo()` cuida disso.
