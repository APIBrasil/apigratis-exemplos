# C# / .NET

Não há SDK oficial em C#. Este exemplo usa só a BCL: `HttpClient` +
`System.Text.Json`.

## Rodando

```bash
dotnet run
```

Credenciais vêm do ambiente (`APIBRASIL_BEARER_TOKEN`, `APIBRASIL_DEVICE_TOKEN`).

| Arquivo | O que mostra |
| --- | --- |
| [ApiBrasilClient.cs](./ApiBrasilClient.cs) | um cliente mínimo: headers, erros tipados, retry só onde é seguro |
| [Program.cs](./Program.cs) | saldo, consulta por crédito, WhatsApp, fila |

## Sobre `HttpClient`

**Uma instância para o processo.** `new HttpClient()` por chamada esgota sockets
(o famoso *socket exhaustion*) porque o socket fica em `TIME_WAIT` depois do
`Dispose`. Em ASP.NET, registre via `IHttpClientFactory`:

```csharp
builder.Services.AddHttpClient<ApiBrasilClient>(c =>
{
    c.BaseAddress = new Uri("https://gateway.apibrasil.io/api/v2/");
    c.DefaultRequestHeaders.Authorization =
        new AuthenticationHeaderValue("Bearer", bearerToken);
});
```

**Barra no fim da `BaseAddress`, sem barra no começo do caminho relativo.**
`new Uri(base, "/whatsapp/sendText")` descarta o path da base — resultado:
404 misterioso. Use `"whatsapp/sendText"`.

**`DeviceToken` não é header de autorização padrão.** Vai em
`DefaultRequestHeaders.Add("DeviceToken", token)` ou por requisição.

## Nuget legado

Existe um pacote `ApiBrasil` no NuGet, publicado por terceiros e sem
manutenção acompanhando o gateway v2. Prefira o `HttpClient` direto — são ~80
linhas, e você controla o retry.
