# Exemplos — SDK Go

SDK: [`github.com/jhowbhz/apigratis-sdk-go`](https://pkg.go.dev/github.com/jhowbhz/apigratis-sdk-go) ·
Repositório: <https://github.com/APIBrasil/apigratis-sdk-go>

Go >= 1.22. **Zero dependências** de runtime — só a biblioteca padrão.

## Rodando

Cada exemplo é um `package main` na sua própria pasta, como manda o Go:

```bash
go mod tidy
cp ../../.env-example ../../.env    # e preencha

# As variáveis precisam estar no ambiente (a SDK lê do ambiente, não de arquivo):
set -a && . ../../.env && set +a    # bash/zsh
go run ./cmd/01-conta-e-saldo
```

No PowerShell:

```powershell
Get-Content ..\..\.env | Where-Object { $_ -match '^\w+=' } | ForEach-Object {
    $nome, $valor = $_ -split '=', 2
    [Environment]::SetEnvironmentVariable($nome.Trim(), $valor.Trim(), 'Process')
}
go run ./cmd/01-conta-e-saldo
```

| Pasta | O que mostra |
| --- | --- |
| [cmd/01-conta-e-saldo](./cmd/01-conta-e-saldo/) | cliente a partir do ambiente, status do gateway, saldo, plano |
| [cmd/02-consultas-por-credito](./cmd/02-consultas-por-credito/) | CNPJ/CPF/veículos, campo `tipo`, homologação, `Decode` em struct |
| [cmd/03-whatsapp](./cmd/03-whatsapp/) | device, sessão, QR Code, envio de texto e mídia, fila |
| [cmd/04-servicos-device](./cmd/04-servicos-device/) | CEP, correios, placa, FIPE, clima, SMS |
| [cmd/05-erros-e-retry](./cmd/05-erros-e-retry/) | sentinelas de erro, `errors.Is`, retry, hooks |

## Particularidades do Go

**`context.Context` em tudo.** Todo método recebe `ctx` como primeiro parâmetro —
é o que cancela e limita a chamada. Um `context.WithTimeout` vale mais que o
`Config.Timeout` porque cobre também os retries.

**Erros por sentinela, não por tipo.** Em vez de `catch (InsufficientBalanceError)`,
use `errors.Is(err, apibrasil.ErrInsufficientBalance)`. Para os detalhes completos
(status, código, corpo), `apibrasil.AsError(err)`.

**Envelope tipado.** As respostas são `map[string]any` com acessores:
`res.Data()`, `res.Balance()`, `res.ValorConsulta()` nas consultas; `res.Response()`,
`res.Message()` nas device-based. E `res.Decode(&minhaStruct)` decodifica direto no
campo útil (`data` ou `response`), sem passar por `json.Marshal` na mão.

## Usando no seu projeto

```bash
go get github.com/jhowbhz/apigratis-sdk-go
```

```go
import "github.com/jhowbhz/apigratis-sdk-go/apibrasil"
```

O `go.mod` daqui aponta para o módulo publicado. Como o repositório da SDK ainda
não tem tags de versão publicadas, o `go get` resolve para uma **pseudo-versão**
(`v0.0.0-<data>-<commit>`) — é o commit mais recente da `main`, e funciona igual.
Para atualizar:

```bash
go get -u github.com/jhowbhz/apigratis-sdk-go@latest
```

Se você estiver desenvolvendo a SDK localmente, adicione um `replace`:

```
replace github.com/jhowbhz/apigratis-sdk-go => ../../../apigratis-sdk-go
```

Os cinco exemplos passam por `go build ./...` e `go vet ./...` sem avisos.
