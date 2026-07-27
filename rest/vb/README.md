# VB.NET

Não há SDK oficial em VB. Este exemplo usa `HttpClient` da BCL.

## Rodando

```bash
dotnet run
```

Credenciais vêm do ambiente (`APIBRASIL_BEARER_TOKEN`, `APIBRASIL_DEVICE_TOKEN`).

| Arquivo | O que mostra |
| --- | --- |
| [Program.vb](./Program.vb) | saldo, consulta por crédito, WhatsApp, Evolution |

## Corrigido em relação ao exemplo antigo

**`WebClient` saiu.** Está obsoleto desde o .NET 6 (`SYSLIB0014`) e não expõe
status HTTP nem `Retry-After` — justamente o que você precisa para tratar 402,
403 e 429. `HttpClient` resolve os dois.

**Credenciais fora do código.** O exemplo anterior tinha o DeviceToken e o
Bearer escritos no fonte. Um arquivo `.vb` comitado com token dentro é uma
credencial vazada — aqui vêm do ambiente.

**Sem `"Bearer "` embutido na variável.** O jeito certo é
`New AuthenticationHeaderValue("Bearer", token)`, com o token puro.
Concatenar o prefixo à mão dá dor de cabeça na hora de trocar de token.

## Uma instância de `HttpClient`

Não crie um por chamada — o socket fica em `TIME_WAIT` depois do `Dispose` e o
processo esgota portas sob carga. Uma instância estática para a vida do
processo, ou `IHttpClientFactory` em ASP.NET.
