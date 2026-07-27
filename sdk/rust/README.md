# Exemplos — SDK Rust

SDK: [`apibrasil`](https://crates.io/crates/apibrasil) ·
Docs: [docs.rs/apibrasil](https://docs.rs/apibrasil) ·
Repositório: <https://github.com/APIBrasil/apigratis-sdk-rust>

Rust >= 1.86. TLS via `rustls` por padrão — não depende de OpenSSL instalado.

## Rodando

```bash
cp ../../.env-example ../../.env    # e preencha

# As variáveis precisam estar no ambiente:
set -a && . ../../.env && set +a    # bash/zsh
cargo run --example 01-conta-e-saldo
```

| Exemplo | O que mostra |
| --- | --- |
| [01-conta-e-saldo](./examples/01-conta-e-saldo.rs) | cliente a partir do ambiente, status do gateway, saldo, plano |
| [02-consultas-por-credito](./examples/02-consultas-por-credito.rs) | CNPJ/CPF/veículos, builder `Consulta`, homologação, `decode()` em struct |
| [03-whatsapp](./examples/03-whatsapp.rs) | device, sessão, QR Code, envio de texto e mídia, fila |
| [04-servicos-device](./examples/04-servicos-device.rs) | CEP, correios, placa, FIPE, clima, SMS |
| [05-erros-e-retry](./examples/05-erros-e-retry.rs) | `ErrorKind`, retry, hooks |

## Particularidades do Rust

**Serviços são funções.** `api.whatsapp()`, `api.consulta()` — e cada método é
`async`, então tudo termina em `.await?`.

**Bodies com `json!`.** Qualquer coisa que implemente `IntoBody` serve:
`json!({...})`, `None`, `()`. Um método que não precisa de corpo aceita `None`.

**Envelope com `Deref`.** `res.data()`, `res.balance()`, `res.response()` são
acessores tipados, mas o envelope também é um `Json` — `res["response"]` funciona.
`res.decode::<MinhaStruct>()?` decodifica direto o campo útil.

**`ErrorKind` em vez de tipos de erro.** Um só `Error`, com a categoria em
`error.kind()` e predicados de conveniência (`error.is_rate_limit()`).

**Cancelamento é do runtime.** Não há parâmetro de timeout por chamada além do
`Config`; use `tokio::time::timeout` em volta do future.

## Cliente síncrono

Sem `async`, com a feature `blocking`:

```toml
apibrasil = { version = "1", features = ["blocking"] }
```

```rust
use apibrasil::blocking::ApiBrasil;

let api = ApiBrasil::from_env()?;
api.whatsapp().send_text(json!({ "number": "5511999999999", "text": "Olá!" }))?;
```
