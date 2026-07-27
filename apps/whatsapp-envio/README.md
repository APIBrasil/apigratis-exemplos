# Envio de WhatsApp

Composer com texto, arquivo, áudio, link e localização — mais verificação de
número e envio por fila.

## Rodando

```bash
cd ..                      # a partir de apps/
APIBRASIL_BEARER_TOKEN=... APIBRASIL_DEVICE_TOKEN_WHATSAPP=... php -S localhost:8000
```

Abra <http://localhost:8000/whatsapp-envio/>.

A sessão precisa estar **iniciada e pareada**. Use
[whatsapp-devices](../whatsapp-devices/) para escanear o QR Code primeiro — este
app só envia.

## Verificar antes de enviar

O botão "Este número tem WhatsApp?" chama `checkNumberStatus`. Vale a chamada
extra: enviar para número sem WhatsApp **consome cota e não entrega nada**. Em
disparo de volume, verificar antes costuma sair mais barato que descobrir depois.

## Uma ação por tipo, não `action` do cliente

O catálogo WPP tem mais de 100 actions, e várias são destrutivas: `clearChat`,
`deleteMessageForEveryone`, `blockContact`, `leaveGroup`. Se o backend aceitasse
`action` como parâmetro, o visitante alcançaria todas.

Por isso a allowlist é **por tipo de mensagem**, cada um com o seu validador de
corpo. Adicionar um tipo novo é declarar uma entrada; nada mais fica exposto.

## Direto ou por fila

| | Direto (`/whatsapp/sendText`) | Fila (`/whatsapp/sendText/queue`) |
| --- | --- | --- |
| Resposta | depois de processar | na hora |
| Erro de envio | vem na resposta | vai para o webhook |
| Use para | envio pontual, com confirmação | volume |

O select "Entrega" troca entre os dois. Para disparo em massa, a fila é o
caminho — um `for` esperando cada envio segura a sua requisição por minutos.

## URL pública, não upload

`sendFile` e `sendAudio` recebem **URL** (`path`), não o arquivo. O gateway baixa
de lá. Duas consequências:

- o arquivo precisa estar acessível publicamente (S3, CDN, seu servidor)
- URL que exige autenticação não funciona

Para enviar bytes direto, existe a action `sendFile64`, que aceita base64 — mais
pesado no corpo da requisição, mas resolve arquivo privado.

## `time_typing`

Simula "digitando…" pelo tempo indicado antes de entregar. Cosmético, mas muda a
percepção de quem recebe — mensagem instantânea de robô é reconhecível.
