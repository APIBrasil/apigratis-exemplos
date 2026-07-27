# Claude Code

O Claude Code fala Streamable HTTP direto — não precisa da ponte `mcp-remote`.

## Adicionando

```bash
claude mcp add --transport http apibrasil https://mcp.apibrasil.cloud/mcp \
  --header "X-Apibrasil-Bearer: SEU_BEARER_TOKEN" \
  --header "DeviceToken: SEU_DEVICE_TOKEN"
```

Escopo: `--scope user` para valer em todos os projetos; sem a flag, fica só no
projeto atual.

## Conferindo

```bash
claude mcp list          # servidores configurados e status da conexão
claude mcp get apibrasil # detalhes deste servidor
```

Dentro do Claude Code, `/mcp` mostra as tools carregadas.

## Removendo

```bash
claude mcp remove apibrasil
```

## Servidor local em vez do remoto

```bash
claude mcp add apibrasil npx -- -y apibrasil-mcp-server stdio
```

E as credenciais no ambiente do processo: `APIBRASIL_BEARER`,
`APIBRASIL_DEVICE_TOKEN`, `APIBRASIL_SECRET_KEY`.

## Testando

> Consulte o CEP 01001000 e me diga o bairro.

Deve chamar `apibrasil.cep.lookup`. Se nada aparecer: `claude mcp list` mostra o
status da conexão, e `bash ../curl/sessao.sh` confirma se as credenciais
funcionam fora do client.
