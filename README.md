# Exemplos — APIBrasil / APIGratis

Exemplos oficiais de integração com a plataforma [APIBrasil](https://apibrasil.com.br):
WhatsApp, SMS, consultas de CPF/CNPJ, veículos, CEP, correios, FIPE, clima, pagamentos e mais.

Todo exemplo aqui roda contra o gateway de produção `https://gateway.apibrasil.io/api/v2`.

## Canais de suporte (Comunidade)

[![WhatsApp Channel](https://img.shields.io/badge/WhatsApp-Channel-25D366?logo=whatsapp)](https://whatsapp.com/channel/0029VaMiaT6B4hdX3hrUcz3X)
[![Telegram Group](https://img.shields.io/badge/Telegram-Group-32AFED?logo=telegram)](https://t.me/apibrasil1)

## Por onde começar

Escolha o **canal** de integração — não a linguagem:

| Você está… | Vá para | Por quê |
| --- | --- | --- |
| Escrevendo código em Node, PHP, Python, Go, Java, Ruby, Rust, C++ ou Flutter | [sdk/](./sdk/) | SDK oficial: autenticação, retry, erros tipados e paginação já resolvidos |
| Numa linguagem sem SDK oficial (C#, Delphi, VB, ASP, C) ou testando no terminal | [rest/](./rest/) | HTTP puro — só os headers certos e o body certo |
| Conectando uma **IA/agente** (Claude, Cursor, VS Code, n8n, Typebot) | [mcp/](./mcp/) | Servidor MCP: o modelo descobre e chama as APIs sozinho |
| Querendo um exemplo **rodando de ponta a ponta** (tela + backend) | [apps/](./apps/) | 14 apps completos, com o token protegido no servidor |

## Credenciais

Pegue as suas em <https://apibrasil.com.br> e copie o arquivo de ambiente:

```bash
cp .env-example .env
```

| Variável | O que é | Onde obter |
| --- | --- | --- |
| `APIBRASIL_BEARER_TOKEN` | JWT da sua conta (identifica **você**) | retorno do login, ou painel → credenciais |
| `APIBRASIL_DEVICE_TOKEN` | Token do device (identifica **uma instância** de um serviço) | painel → device criado, ou `devices/store` |
| `APIBRASIL_SECRET_KEY` | Chave da API — usada **só** para criar devices | painel → API → SecretKey |
| `APIBRASIL_BASE_URL` | Base do gateway | opcional, o padrão já é produção |

Todas as SDKs leem essas quatro variáveis automaticamente: `new ApiBrasil()` sem argumento
já vem autenticado.

## As duas famílias de serviço

Isso explica 90% dos erros de integração. A plataforma tem **dois modelos de cobrança e de
autenticação**, e o header que falta muda conforme a família:

| Família | Headers | Cobrança | Serviços |
| --- | --- | --- | --- |
| **Device-based** | `Authorization: Bearer` **+** `DeviceToken` | por device/plano | WhatsApp, Evolution, SMS, veículos, CEP, correios, FIPE, DDD, feriados, tradução, clima, OCR, geolocalização |
| **Por créditos** | `Authorization: Bearer` | debita saldo por consulta | `consulta/cpf`, `consulta/cnpj`, `consulta/veiculos`, `consulta/cep`, Serasa, CNH, telefone |

Nas rotas por crédito, `DeviceToken` é ignorado — e nas device-based, a ausência dele dá **403**.
Consultas por crédito aceitam `"homolog": true` no body para rodar em **sandbox, sem cobrança**.

### Como o gateway roteia

```
POST /api/v2/{servico}/{action}          → device-based   (ex: /whatsapp/sendText)
POST /api/v2/{servico}/{action}/queue    → mesma coisa, assíncrono via fila
POST /api/v2/consulta/{servico}/credits  → por créditos   (ex: /consulta/cnpj/credits)
POST /api/v2/evolution/{controller}/{action}
```

Como as rotas são catch-all, **toda** API do catálogo é alcançável mesmo sem método dedicado
na SDK — use o `request(action, body)` de cada serviço ou o `request(method, path, body)` do
cliente. Catálogo vivo em `GET /api/v2/apis`, template de body em `GET /api/v2/endpoint/body`.

## Erros que valem conhecer

O gateway usa status HTTP com semântica — as SDKs traduzem cada um numa classe/sentinela:

| HTTP | Significa | Ação |
| --- | --- | --- |
| 400 / 422 | payload inválido | confira o body em <https://doc.apibrasil.io> |
| 401 | bearer ausente ou expirado | refaça o login |
| 402 | sem saldo/créditos | recarregue |
| 403 | sem permissão: device errado, IP fora da whitelist, API que exige PJ | confira `DeviceToken` e a whitelist |
| 404 / 410 | sem dados, ou rota desativada | 410 é rota morta — veja a mensagem, ela aponta a nova |
| 429 | limite por minuto atingido | respeite `Retry-After` (as SDKs já refazem) |
| 5xx | falha do gateway ou do provedor | retry com backoff |

As SDKs **não** repetem timeouts nem erros de negócio automaticamente — só 429 e falha de
conexão. Isso é deliberado: repetir um `sendText` que deu timeout duplica a mensagem, e
repetir uma consulta duplica a cobrança.

## Estrutura

```
├── sdk/      exemplos com as SDKs oficiais (9 linguagens, mesma numeração em todas)
├── rest/     HTTP puro: curl, C#, Delphi, VB, ASP, C, navegador
├── mcp/      Model Context Protocol: clients, configs de IDE e de clientes de IA
└── apps/     14 aplicações completas (front-end + backend proxy)
```

Em `sdk/`, os arquivos têm a **mesma numeração em toda linguagem** — `03-whatsapp` faz a mesma
coisa em Go e em PHP. Serve para comparar idiomas e para portar código entre stacks:

| # | Exemplo | Cobre |
| --- | --- | --- |
| 01 | conta e saldo | cliente a partir do ambiente, status do gateway, saldo, plano |
| 02 | consultas por crédito | CPF, CNPJ, veículos, `tipo`, homologação, leitura do envelope |
| 03 | WhatsApp | criar device, sessão, QR Code, envio de texto/mídia, fila |
| 04 | serviços device-based | CEP, correios, veículos, FIPE, clima, SMS |
| 05 | erros e retry | erros tipados, política de retry, hooks de observabilidade |

## Documentação

- Portal e credenciais: <https://apibrasil.com.br>
- Referência das APIs: <https://doc.apibrasil.io>
- Status: <https://status.apibrasil.com.br>

## Licença

MIT.
