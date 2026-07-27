# ASP clássico (VBScript)

Para manutenção de sistemas legados em IIS. Usa `MSXML2.ServerXMLHTTP`.

| Arquivo | O que mostra |
| --- | --- |
| [apibrasil.asp](./apibrasil.asp) | funções reutilizáveis: POST JSON, leitura de status e erro |
| [exemplo.asp](./exemplo.asp) | saldo, consulta CNPJ, envio de WhatsApp |

## Corrigido em relação ao exemplo antigo

**`ServerXMLHTTP`, não `XMLHTTP`.** No servidor, `MSXML2.ServerXMLHTTP` é o
objeto correto: tem timeout configurável e não usa o cache/proxy do WinINET.
O `MSXML2.XMLHTTP` é para o lado cliente.

**Headers que não existem.** O exemplo antigo mandava `PublicToken` e
`SecretKey` em `/whatsapp/sendText`. Nenhum dos dois é usado ali —
`SecretKey` serve só em `/devices/store`, e `PublicToken` não existe no gateway.

**UTF-8 na resposta.** `.responseText` interpreta o corpo como Latin-1 se o
servidor não mandar charset explícito, e o acento vira `Ã§`. A função
`LerRespostaUtf8` converte via `ADODB.Stream` a partir de `.responseBody`.

**Credenciais fora do fonte.** Vêm de variáveis de aplicação/ambiente do IIS,
não escritas no `.asp`.

## Configurando as credenciais no IIS

Em **Configuration Editor** → `system.webServer/asp` → `appSettings`, ou por
variável de ambiente do pool de aplicação. No código:

```vbscript
bearer = GetEnvVar("APIBRASIL_BEARER_TOKEN")
```

Nunca comite um `.asp` com token dentro — o arquivo é servido pelo IIS, e uma
falha de configuração pode expor o fonte.

## Timeouts

```vbscript
' resolveTimeout, connectTimeout, sendTimeout, receiveTimeout — em ms
http.setTimeouts 5000, 5000, 15000, 30000
```

Sem isso, uma chamada travada pode segurar um worker do IIS indefinidamente.
