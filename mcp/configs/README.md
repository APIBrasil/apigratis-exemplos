# Configurações de client MCP

Copie o JSON do seu client, troque os placeholders pelas suas credenciais
(<https://apibrasil.com.br>) e reinicie o app.

| Client | Arquivo daqui | Onde colar |
| --- | --- | --- |
| Claude Desktop | [claude_desktop_config.json](./claude_desktop_config.json) | `%APPDATA%\Claude\claude_desktop_config.json` (Windows) · `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS) |
| Claude Code | [claude_code.md](./claude_code.md) | via `claude mcp add` |
| Cursor | [cursor_mcp.json](./cursor_mcp.json) | `.cursor/mcp.json` no projeto, ou `~/.cursor/mcp.json` |
| VS Code | [vscode_mcp.json](./vscode_mcp.json) | `.vscode/mcp.json` no projeto |

## Duas formas de conectar

### Remoto via ponte `mcp-remote` (recomendado)

O servidor da APIBrasil é Streamable HTTP. Clients que só falam `stdio` usam a
ponte oficial [`mcp-remote`](https://www.npmjs.com/package/mcp-remote), que
converte `stdio` ⇆ Streamable HTTP e **injeta as credenciais por header**:

```jsonc
{
  "command": "npx",
  "args": [
    "-y", "mcp-remote", "https://mcp.apibrasil.cloud/mcp",
    "--header", "X-Apibrasil-Bearer:${APIBRASIL_BEARER}",
    "--header", "DeviceToken:${APIBRASIL_DEVICE_TOKEN}"
  ],
  "env": { "APIBRASIL_BEARER": "...", "APIBRASIL_DEVICE_TOKEN": "..." }
}
```

Credencial por header não entra no contexto do modelo. É o motivo de preferir
essa forma.

### Servidor local via `npx`

Roda o MCP na sua máquina, falando direto com o gateway:

```jsonc
{
  "command": "npx",
  "args": ["-y", "apibrasil-mcp-server", "stdio"],
  "env": {
    "APIBRASIL_BEARER": "SEU_TOKEN",
    "APIBRASIL_DEVICE_TOKEN": "SEU_DEVICE",
    "APIBRASIL_TOOLS_PROFILE": "core"
  }
}
```

Vale quando você quer controlar o profile de tools, ligar `ENABLE_*` específicos
ou depurar com logs locais.

## Variáveis do servidor

| Variável | Para quê |
| --- | --- |
| `APIBRASIL_BEARER` | JWT da conta (note: **sem** o sufixo `_TOKEN`, diferente das SDKs) |
| `APIBRASIL_DEVICE_TOKEN` | device dos serviços device-based |
| `APIBRASIL_SECRET_KEY` | criar devices |
| `APIBRASIL_TOOLS_PROFILE` | `core` (~26 tools, padrão) ou `full` (~223) |
| `APIBRASIL_LEGACY_TOOL_NAMES` | `1` registra também os nomes 1.x como alias |
| `APIBRASIL_BALANCE_PRECHECK` | pré-checagem de saldo (desligada por padrão) |
| `MCP_AUTH_TOKEN` | protege o `/mcp` do **seu** deploy — não é o token da APIBrasil |

## Depois de configurar

Peça ao modelo algo como:

> Consulte o CEP 01001000 e me diga o bairro.

Ele deve chamar `apibrasil.cep.lookup` sozinho. Se não aparecer nenhuma tool,
confira nesta ordem: JSON válido → app reiniciado → `bash ../curl/sessao.sh`
funciona com as mesmas credenciais.

## Sobre auto-aprovação

Consultas puras são marcadas `readOnlyHint` e são seguras de auto-aprovar.
**Consultas tarifadas não são** — debitar crédito é efeito colateral. Envios,
exclusões, recargas e ligações são `destructiveHint`. Deixe essas pedindo
confirmação, a não ser que você queira que o agente gaste saldo sozinho.
