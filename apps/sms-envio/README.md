# Envio de SMS

Envio para um ou vários números, com relatório de entrega por destinatário.

## Rodando

```bash
cd ..                      # a partir de apps/
APIBRASIL_BEARER_TOKEN=... APIBRASIL_DEVICE_TOKEN_SMS=... php -S localhost:8000
```

Abra <http://localhost:8000/sms-envio/>.

**Em homologação (padrão) nada é enviado de verdade.** Só com
`APIBRASIL_HOMOLOG=0` e a opção "Crédito" os envios são reais — e cobrados.

## Duas rotas

| Rota | Autenticação | Cobrança |
| --- | --- | --- |
| `POST /sms/send` | Bearer + **DeviceToken** | por device/plano |
| `POST /sms/send/credits` | Bearer | debita saldo |

Só a segunda aceita `homolog` — a de device sempre envia. É por isso que o aviso
no topo do app fala das duas condições.

## 160 caracteres não é capricho

É o limite de um SMS single-part em GSM-7. Acima disso a operadora fragmenta a
mensagem e **cobra cada parte**. O campo trava em 160 com contador visível, e o
backend rejeita acima disso — a surpresa de pagar 3× por uma mensagem é comum e
evitável.

## Envio sequencial, de propósito

O loop no front é sequencial com 350 ms de pausa, não `Promise.all`. Dois motivos:

1. **Rate limit.** Vinte chamadas simultâneas batem no limite por minuto e as
   últimas voltam 429.
2. **Saber onde parou.** Com envio paralelo e um 429 no meio, você não sabe quais
   foram e quais não — e reenviar duplica cobrança.

O app também **interrompe** o lote quando o erro é de saldo ou de autenticação:
esses não melhoram no próximo número.

## Teto de 20 por lote

Trava contra o acidente clássico de colar uma lista de 5.000 linhas. Para volume
real, o caminho é a fila do gateway (sufixo `/queue`) ou um worker no seu
backend — não um `for` no navegador.

## Relatório por número

A tabela é montada antes dos envios e cada linha vai sendo atualizada
("na fila" → "enviando" → "enviado"/"falhou"). Além de dar feedback, é o registro
de quem recebeu — exportável em CSV, porque essa informação costuma ser cobrada
de você depois.
