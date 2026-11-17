
# Consulta FIPE via WhatsApp

Aplicação web desenvolvida com JavaScript, Node.js e Express.

## Funcionalidades

- Consulta de veículos pela placa utilizando a APIBrasil.
- Identificação do resultado FIPE principal.
- Exibição de marca, modelo, ano e valor FIPE.
- Envio das informações para um número de WhatsApp autorizado.
- Validação de placa e telefone.
- Limitação de requisições por IP.
- Proteção das credenciais no backend.

## Tecnologias

- HTML5
- CSS3
- JavaScript
- Node.js
- Express
- APIBrasil
- Fetch API
- express-rate-limit

## Como executar

### 1. Instalar as dependências

```bash
npm install
```

### 2. Configurar as variáveis de ambiente

Crie um arquivo `.env` na pasta principal:

```env
APIBRASIL_TOKEN=seu_token
WHATSAPP_DEVICE_TOKEN=seu_device_token
PORT=3001
```

### 3. Iniciar o servidor

```bash
node --env-file=.env server.js
```

### 4. Acessar a aplicação

Abra no navegador:

http://localhost:3001

## Funcionamento

1. O usuário informa a placa e o telefone.
2. O frontend envia os dados ao backend usando `fetch()`.
3. O backend valida os dados.
4. A APIBrasil retorna as informações do veículo.
5. O sistema identifica o resultado FIPE principal.
6. O backend solicita o envio da mensagem pelo WhatsApp.
7. O frontend apresenta os dados do veículo e o resultado da solicitação.

## Segurança

As credenciais são armazenadas no arquivo `.env`, que não deve ser enviado ao GitHub.

O sistema possui validação de entradas e limitação básica de requisições. Para disponibilização pública, são recomendados controles adicionais de autenticação e prevenção de abuso.


## Webhook do WhatsApp

O projeto possui um endpoint para receber notificações da APIBrasil:

`POST /webhook/whatsapp/:secret`

### Funcionalidades
- Recebimento de notificações em tempo real.
- Identificação de mensagens recebidas (`RECEIVE_MESSAGE`).
- Acompanhamento de status das mensagens (`MESSAGE_STATUS`).
- Validação de um identificador secreto na URL.
- Integração com ngrok para testes locais via HTTPS.

### Configuração

Defina a variável `WEBHOOK_SECRET` no arquivo `.env`.

Para testar localmente, inicie o servidor Node.js e execute:

`ngrok http 3001`

Configure a URL HTTPS gerada pelo ngrok no campo de recebimento de mensagens do dispositivo na APIBrasil, acrescentando `/webhook/whatsapp/` e o identificador secreto.

**Segurança:** a implementação utiliza um segredo na URL para testes. Não realiza validação de assinatura HMAC e não deve ser considerada pronta para produção.
