# Delphi

Não há SDK oficial em Delphi. Estes exemplos usam **Indy** (`TIdHTTP`), que vem
com o Delphi.

| Arquivo | O que mostra |
| --- | --- |
| [ApiBrasil.pas](./ApiBrasil.pas) | unit reutilizável: headers, POST JSON, leitura do erro |
| [ExemploConsole.dpr](./ExemploConsole.dpr) | saldo, consulta CNPJ, WhatsApp, Evolution |

## Corrigido em relação aos exemplos antigos

**Vazamento de memória.** `http.Post(url, TStringStream.Create(data))` cria um
stream que **nunca é liberado** — o `TIdHTTP.Post` não assume a posse dele.
O jeito certo é uma variável e `try/finally`:

```pascal
Corpo := TStringStream.Create(Json, TEncoding.UTF8);
try
  Resposta := Http.Post(Url, Corpo);
finally
  Corpo.Free;
end;
```

**Encoding.** Sem `TEncoding.UTF8` no stream, acento no texto da mensagem chega
corrompido no WhatsApp.

**TLS.** O Indy precisa de um `TIdSSLIOHandlerSocketOpenSSL` explícito para
falar HTTPS, senão dá "Could not load SSL library". Também é preciso ter as DLLs
do OpenSSL junto ao executável.

**Erro HTTP vira exceção.** O `TIdHTTP` lança `EIdHTTPProtocolException` em
status >= 400 — e a mensagem do gateway está em `E.ErrorMessage`, não em
`E.Message`. É ali que está a informação útil (qual campo faltou, quanto custava
a consulta). Alternativa: `Http.HTTPOptions := [hoNoProtocolErrorException]` e
checar `Http.ResponseCode`.

**Headers que não existem.** Os exemplos antigos mandavam `PublicToken` e
`SecretKey` em `/whatsapp/sendText`. Nenhum dos dois é usado ali — `SecretKey`
serve só em `/devices/store`, e `PublicToken` não existe no gateway.

## Requisitos de TLS

Baixe as DLLs do OpenSSL compatíveis com a sua versão do Indy
(`libeay32.dll` + `ssleay32.dll`, ou `libcrypto-1_1.dll` + `libssl-1_1.dll`
nas versões novas) e deixe na pasta do executável.
