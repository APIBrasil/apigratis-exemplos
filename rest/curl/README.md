# curl

O contrato do gateway na forma mais legível. Serve para testar credencial,
depurar um 403 e entender o que a SDK faz por baixo.

## Rodando

```bash
set -a && . ../../.env && set +a    # carrega o .env da raiz
bash 01-login-e-saldo.sh
```

No Windows, use o Git Bash (ou WSL) — os scripts são POSIX.

| Arquivo | O que faz |
| --- | --- |
| [01-login-e-saldo.sh](./01-login-e-saldo.sh) | login por email/senha, extrai o bearer, consulta saldo e plano |
| [02-consultas-por-credito.sh](./02-consultas-por-credito.sh) | CPF/CNPJ/veículos com `tipo` e `homolog` |
| [03-whatsapp.sh](./03-whatsapp.sh) | cria device com SecretKey, inicia sessão, QR Code, envia texto e arquivo |
| [04-servicos-device.sh](./04-servicos-device.sh) | CEP, correios, placa, FIPE, clima, SMS |
| [05-erros-e-retry.sh](./05-erros-e-retry.sh) | como ler cada status e um retry que não duplica cobrança |

## Uma linha só, para testar credencial

```bash
curl -sS https://gateway.apibrasil.io/api/v2/balance \
  -H "Authorization: Bearer $APIBRASIL_BEARER_TOKEN"
```

Se isso responde, sua credencial está válida. Se dá 401, o resto não vai
funcionar.

## Dicas de flags

- `-sS` — silencioso, mas ainda mostra erro. É o padrão para script.
- `-i` ou `-D -` — inclui os headers da resposta. Necessário para ler
  `Retry-After` num 429.
- `-w '\n%{http_code}\n'` — imprime o status separado do corpo, o que permite
  ramificar no shell.
- `--fail-with-body` — sai com código != 0 em erro HTTP **e** ainda imprime o
  corpo (o `-f` puro descarta o corpo, que é justo onde está a mensagem).
- `-d @arquivo.json` — body de arquivo, melhor que escapar JSON inline.
