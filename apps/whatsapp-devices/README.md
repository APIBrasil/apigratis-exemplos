# Gestão de devices WhatsApp

Lista os devices da conta, mostra o status de conexão de cada um e o QR Code
para parear.

## Rodando

```bash
cd ..                      # a partir de apps/
APIBRASIL_BEARER_TOKEN=... php -S localhost:8000
```

Abra <http://localhost:8000/whatsapp-devices/>.

O `DeviceToken` vem da própria lista — este app é multi-device, então não precisa
de `APIBRASIL_DEVICE_TOKEN` no ambiente.

## Arquivos

| Arquivo | O que é |
| --- | --- |
| [index.html](./index.html) | tabela de devices, status e modal com o QR Code |
| [backend.php](./backend.php) | proxy com allowlist: listar, status, QR Code, iniciar, encerrar |

## O que mudou em relação ao exemplo antigo

O `whatsapp/Javascript/lista-devices` do repositório antigo tinha **um JWT real
comitado dentro do `example.js`**. Aquele token já expirou (fevereiro de 2024),
mas o padrão é o problema: qualquer token no front-end é um token vazado.

Aqui o front não conhece credencial nenhuma — chama `backend.php`, que adiciona
o `Authorization` no servidor.

## Device × sessão

Duas coisas diferentes que costumam ser confundidas:

- **Device** é o registro na sua conta: existe no painel, tem um `device_token`,
  aparece em `GET /devices`. Criar um device não conecta nada.
- **Sessão** é a conexão viva com o WhatsApp: começa em `/whatsapp/start`,
  precisa do QR Code escaneado, e cai se o celular ficar muito tempo offline.

Um device pode existir com a sessão desconectada — é o caso mais comum quando
"paramos de receber mensagens". O `getConnectionStatus` é o que diz qual dos dois
está com problema.

## Registrando webhooks

Os webhooks são registrados no `/whatsapp/start`, e **só** ali:

```json
{
  "webhook_wh_message": "https://seu-app.com/webhook/mensagem",
  "webhook_wh_status":  "https://seu-app.com/webhook/status",
  "webhook_wh_connect": "https://seu-app.com/webhook/conexao",
  "webhook_wh_qrcode":  "https://seu-app.com/webhook/qrcode"
}
```

Sem eles, você só descobre mensagem recebida por polling. Este app deixa os
campos configuráveis por variável de ambiente (`WEBHOOK_MENSAGENS`, etc).
