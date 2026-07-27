# Exemplos — SDK Ruby

SDK: [`apigratis-sdk-ruby`](https://rubygems.org/gems/apigratis-sdk-ruby) ·
Repositório: <https://github.com/APIBrasil/apigratis-sdk-ruby>

Ruby >= 3.0. Sem dependências de runtime — o transporte padrão é a stdlib
(`net/http`), e o Faraday é usado automaticamente quando já está carregado no
processo. Toda resposta volta como **Hash** com chaves em `String`, exatamente
como vêm da API.

## Rodando

```bash
bundle install
cp ../../.env-example ../../.env    # e preencha
ruby 01_conta_e_saldo.rb
```

Os exemplos carregam o `.env` da raiz com [`env.rb`](./env.rb) — sem depender de
`dotenv`. Em produção, exporte as variáveis e a SDK as lê sozinha.

| Arquivo | O que mostra |
| --- | --- |
| [01_conta_e_saldo.rb](./01_conta_e_saldo.rb) | cliente a partir do ambiente, status do gateway, saldo, plano |
| [02_consultas_por_credito.rb](./02_consultas_por_credito.rb) | CNPJ/CPF/veículos, campo `tipo`, homologação, envelope de cobrança |
| [03_whatsapp.rb](./03_whatsapp.rb) | device, sessão, QR Code, envio de texto e mídia, fila |
| [04_servicos_device.rb](./04_servicos_device.rb) | CEP, correios, placa, FIPE, clima, SMS |
| [05_erros_e_retry.rb](./05_erros_e_retry.rb) | erros tipados, política de retry, hooks |

## Rails

Um cliente por processo, em `config/initializers/apibrasil.rb`:

```ruby
APIBRASIL = ApiBrasil.new(
  bearer_token: Rails.application.credentials.dig(:apibrasil, :bearer),
  device_token: Rails.application.credentials.dig(:apibrasil, :device)
)
```

```ruby
class NotificarJob < ApplicationJob
  retry_on ApiBrasil::ServerError, wait: :polynomially_longer, attempts: 3
  discard_on ApiBrasil::InsufficientBalanceError

  def perform(numero, texto)
    APIBRASIL.whatsapp.send_text("number" => numero, "text" => texto)
  end
end
```

`discard_on` para o erro de saldo evita uma fila entupida de jobs que nunca vão
passar. `retry_on` só nos erros de servidor — nunca em timeout, que pode ter sido
entregue.

## Chaves em String

A SDK envia o Hash como você monta. Como a API espera chaves em `String`, use
`"number" => ...` em vez de `number:` para não depender de conversão implícita —
é o estilo de todos os exemplos aqui.
