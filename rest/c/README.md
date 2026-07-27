# C (libcurl)

Não há SDK oficial em C. Este exemplo usa **libcurl**, e nada mais.

## Compilando

```bash
# Linux / macOS
cc apibrasil.c -o apibrasil -lcurl

# Windows (MSYS2 / MinGW)
gcc apibrasil.c -o apibrasil.exe -lcurl

# Ubuntu/Debian, se faltar o header:
sudo apt install libcurl4-openssl-dev
```

## Rodando

```bash
export APIBRASIL_BEARER_TOKEN=...
export APIBRASIL_DEVICE_TOKEN=...     # opcional
export NUMERO=5511999999999           # opcional
./apibrasil
```

| Arquivo | O que mostra |
| --- | --- |
| [apibrasil.c](./apibrasil.c) | callback de escrita, headers, status HTTP, saldo, consulta, WhatsApp |

## Corrigido em relação ao exemplo antigo

**A resposta era descartada.** Sem `CURLOPT_WRITEFUNCTION`, o libcurl imprime o
corpo em `stdout` e o programa não tem acesso a ele. Aqui há um buffer que cresce
sob demanda — dá para inspecionar e parsear.

**Status HTTP era ignorado.** `curl_easy_perform` retorna `CURLE_OK` mesmo num
HTTP 402 ou 403: `CURLE_OK` só quer dizer que a conversa aconteceu. Para saber
se deu certo, é preciso `curl_easy_getinfo(..., CURLINFO_RESPONSE_CODE, ...)`.

**Headers que não existem.** O exemplo antigo mandava `PublicToken` e
`SecretKey` em `/whatsapp/sendText`. Nenhum dos dois é usado ali —
`SecretKey` serve só em `/devices/store`, e `PublicToken` não existe no gateway.

**Credenciais fora do fonte.** Vêm de `getenv`, não escritas no `.c`.

**`curl_global_init`.** Chamado uma vez no início e `curl_global_cleanup` no
fim, como manda a documentação — sem isso a inicialização acontece
implicitamente no primeiro `curl_easy_init`, o que não é thread-safe.

## Sobre timeouts

`CURLOPT_TIMEOUT 0` (o padrão, e o que estava no exemplo antigo) significa
**esperar para sempre**. Aqui há `CURLOPT_TIMEOUT` e
`CURLOPT_CONNECTTIMEOUT` definidos.

E não desabilite a verificação de TLS: `CURLOPT_SSL_VERIFYPEER 0` deixa a
conexão vulnerável a interceptação — junto com o seu Bearer Token.
