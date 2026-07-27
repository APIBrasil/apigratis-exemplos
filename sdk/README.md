# Exemplos com as SDKs oficiais

Nove linguagens, **mesma superfície de API**. O que muda é só o idioma:

```
api.whatsapp.sendText({ number, text })   // Node, PHP, Python, Java, Ruby, Dart
api.WhatsApp.SendText(ctx, ...)           // Go
api.whatsapp().send_text(json!({...}))    // Rust
api.whatsapp.sendText({{...}})            // C++
```

## Instalação

| Linguagem | Pacote | Instalação | Requer |
| --- | --- | --- | --- |
| [nodejs/](./nodejs/) | `apigratis-sdk-nodejs` | `npm i apigratis-sdk-nodejs` | Node >= 18 |
| [php/](./php/) | `jhowbhz/apigratis-sdk-php` | `composer require jhowbhz/apigratis-sdk-php` | PHP >= 8.0 |
| [python/](./python/) | `api-brasil` | `pip install api-brasil` | Python >= 3.8 |
| [go/](./go/) | `github.com/jhowbhz/apigratis-sdk-go` | `go get github.com/jhowbhz/apigratis-sdk-go` | Go >= 1.22 |
| [java/](./java/) | `br.com.apibrasil:apigratis-sdk-java` | Maven / Gradle | Java >= 17 |
| [ruby/](./ruby/) | `apigratis-sdk-ruby` | `gem install apigratis-sdk-ruby` | Ruby >= 3.0 |
| [rust/](./rust/) | `apibrasil` | `cargo add apibrasil` | Rust >= 1.86 |
| [cpp/](./cpp/) | `apibrasil::apibrasil` | CMake (FetchContent) | C++17 + libcurl |
| [flutter/](./flutter/) | `apigratis_sdk_flutter` | `flutter pub add apigratis_sdk_flutter` | Dart >= 3.5 |

## Os cinco exemplos

A numeração é a mesma em todas as pastas — dá para ler o `03` em Ruby e portar para Rust.

| # | Faz | Precisa de |
| --- | --- | --- |
| **01** conta e saldo | monta o cliente a partir do ambiente, checa o gateway, lê saldo e plano | bearer |
| **02** consultas por crédito | CNPJ, CPF e veículos; campo `tipo`; homologação; lê `valor_consulta` e saldo restante | bearer + saldo (ou `homolog`) |
| **03** WhatsApp | cria o device com a SecretKey, inicia sessão, pega o QR Code, envia texto/arquivo, enfileira | bearer + SecretKey/device |
| **04** serviços device-based | CEP, rastreio dos Correios, dados e FIPE por placa, clima, SMS | bearer + device |
| **05** erros e retry | trata cada erro tipado, configura retry e liga hooks de observabilidade | bearer |

## Antes de rodar

```bash
cp ../.env-example ../.env   # na raiz do repositório
```

Preencha `APIBRASIL_BEARER_TOKEN` e, para os exemplos 03/04, `APIBRASIL_DEVICE_TOKEN`
(ou `APIBRASIL_SECRET_KEY`, se quiser que o 03 crie o device para você).

Os exemplos **não** trazem credencial embutida: todos leem do ambiente e avisam o que falta.

## Detalhes que valem saber

**Homologação.** Não existe URL de sandbox. As consultas por crédito aceitam
`"homolog": true` no body e respondem com dados fictícios, sem debitar. Use isso no CI.

**Múltiplos devices no mesmo processo.** `withDevice(token)` devolve um cliente novo
apontando para outro device, sem mexer no original — é assim que se roda várias sessões de
WhatsApp de uma vez.

**Endpoint sem método dedicado.** Toda SDK tem duas saídas de escape, já com os headers de
autenticação: `api.<servico>.request(action, body)` e `api.request(method, path, body)`.
Nenhuma API do catálogo fica inacessível.

**O case da action importa.** Ao usar `request(action, ...)`, a action vai **verbatim** para o
provedor — o gateway monta a URL com `$endpoint . '/' . $action`. Duas pegadinhas conhecidas:

| Correto | Errado |
| --- | --- |
| `ConsultarMarcas`, `ConsultarModelos`, `ConsultarValorComTodosParametros` | `consultarMarcas` (camelCase) |
| `/holidays/feriados` | `/holidays/holidays` |

Com o case errado, o erro vem do provedor lá em cima e a mensagem não deixa óbvio que o
problema era uma letra maiúscula. Os métodos nomeados das SDKs já mandam a string certa — a
armadilha só existe no `request()` genérico. Para conferir o nome exato, use o catálogo gerado
(`Catalog.actionsOf('fipe')`) ou `GET /api/v2/apis`.

**Retry.** Ligado por padrão só em 429 e falha de conexão. Timeout e erro de negócio nunca
são repetidos — repetir um envio ou uma consulta que talvez tenha completado custa dinheiro.
