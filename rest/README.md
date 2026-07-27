# REST puro — sem SDK

Para quando não existe SDK oficial da sua linguagem, ou você só quer testar no
terminal. Aqui é HTTP na mão: a URL certa, os headers certos, o body certo.

Se a sua linguagem tem SDK ([Node, PHP, Python, Go, Java, Ruby, Rust, C++,
Flutter](../sdk/)), use — retry, erros tipados e paginação já vêm resolvidos.

## O contrato, em quatro linhas

```
POST https://gateway.apibrasil.io/api/v2/{servico}/{action}
Content-Type: application/json
Authorization: Bearer <APIBRASIL_BEARER_TOKEN>
DeviceToken: <APIBRASIL_DEVICE_TOKEN>      ← só nos serviços device-based
```

Consultas por crédito (`/consulta/{servico}/credits`) usam **só** o
`Authorization` — o `DeviceToken` é ignorado.

### Headers que NÃO existem

Exemplos antigos circulam com `PublicToken` e `SecretKey` em rotas de envio.
Isso está errado:

- **`PublicToken`** não é usado por nenhuma rota do gateway. Remova.
- **`SecretKey`** só serve em `POST /devices/store`, para criar um device.
  Em `/whatsapp/sendText` e afins, não tem função.

Mandar header extra não quebra a chamada, mas passa a credencial errada adiante
e confunde quem copia o exemplo.

## Conteúdo

| Pasta | Para |
| --- | --- |
| [curl/](./curl/) | terminal, CI, depuração. **Comece aqui** — é o contrato mais legível |
| [csharp/](./csharp/) | C# / .NET (`HttpClient`) |
| [delphi/](./delphi/) | Delphi (Indy `TIdHTTP`) |
| [vb/](./vb/) | VB.NET |
| [asp/](./asp/) | ASP clássico (`MSXML2.ServerXMLHTTP`) |
| [c/](./c/) | C (libcurl) |
| [browser/](./browser/) | JavaScript no navegador — **leia o aviso** |

## Aviso: navegador

Chamar o gateway direto do navegador expõe o seu Bearer Token para qualquer
visitante — está no DevTools, no bundle, no histórico. Um token vazado dá acesso
à sua conta e ao seu saldo.

O padrão correto é um proxy no seu backend:

```
navegador  →  seu backend (guarda o token)  →  gateway APIBrasil
```

[browser/](./browser/) mostra as duas versões, e [apps/](../apps/) traz apps
completos com o proxy pronto.

## Erros

Status HTTP com semântica: 400/422 payload, 401 bearer, 402 saldo, 403
device/IP/PJ, 404 sem dados, 410 rota morta, 429 limite, 5xx servidor. A tabela
completa está no [README raiz](../README.md#erros-que-valem-conhecer).

Sem SDK, **você** implementa o retry. Duas regras que valem dinheiro:

1. Repita só em **429** e falha de conexão. Respeite o `Retry-After`.
2. **Nunca** repita timeout às cegas — a operação pode ter completado, e você
   duplica uma mensagem enviada ou uma consulta cobrada.
