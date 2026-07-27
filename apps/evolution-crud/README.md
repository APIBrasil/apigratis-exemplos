# CRUD de instâncias Evolution

Cria, conecta, consulta o estado, reinicia e apaga instâncias da Evolution API
pelo gateway da APIBrasil.

## Rodando

```bash
cd ..                      # a partir de apps/
APIBRASIL_BEARER_TOKEN=... APIBRASIL_SECRET_KEY=... php -S localhost:8000
```

Abra <http://localhost:8000/evolution-crud/>.

A `SecretKey` (painel → API Evolution → SecretKey) é necessária **só para criar
devices**. Sem ela, o app funciona para listar, conectar e apagar — só o botão
"Criar device" fica desabilitado.

## Arquivos

| Arquivo | O que é |
| --- | --- |
| [index.html](./index.html) | tabela de instâncias com as ações |
| [backend.php](./backend.php) | proxy com allowlist das rotas Evolution |

## O que mudou em relação ao exemplo antigo

O `evolution/PHP/crud/backend.php` do repositório antigo estava **vazio** — o
front chamava o gateway direto do JavaScript, com o token no cliente. E o
`teste-baileys/utils.php` tinha três problemas sérios:

| Antes | Agora |
| --- | --- |
| Bearer Token escrito no fonte | vem de `getenv()` no servidor |
| `CURLOPT_SSL_VERIFYPEER => false` | verificação de TLS ligada |
| `cluster.apigratis.com` (base antiga) | `gateway.apibrasil.io/api/v2` |

Desligar a verificação de TLS deixa a conexão aberta a interceptação — e o que
trafega ali é justamente o seu Bearer Token.

## As rotas

Evolution tem um nível a mais que os outros serviços:
`/evolution/{controller}/{action}`.

| Ação | Rota | Body |
| --- | --- | --- |
| criar instância | `/evolution/instance/create` | `{ instanceName, qrcode: true }` |
| estado | `/evolution/instance/connectionState` | `{}` |
| reiniciar | `/evolution/instance/restart` | `{}` |
| apagar | `/evolution/instance/delete` | `{}` |
| enviar texto | `/evolution/message/sendText` | `{ number, textMessage: { text } }` |

O `instanceName` **precisa ser igual ao `device_name`** do device — é assim que
o gateway amarra a instância ao seu device.

## Device × instância

- **Device** (`POST /devices/store`, com `SecretKey`) é o registro na sua conta.
  Precisa de um `server_search`, que vem de `GET /servers`.
- **Instância** (`POST /evolution/instance/create`, com `DeviceToken`) é a
  conexão Evolution em si, e é ela que gera o QR Code.

São duas etapas. Criar o device não cria a instância.

## O QR Code

Na Evolution ele vem em `response.qrcode.base64` — diferente da API WhatsApp
nativa, onde está em `response.qrcode`. O front trata os dois caminhos.
