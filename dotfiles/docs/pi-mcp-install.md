# Pi MCP setup

Guía rápida para reconstruir los MCP servers usados por Pi en este entorno.

## Quick path

1. Instalar el adapter MCP de Pi:

   ```bash
   pi install npm:pi-mcp-adapter
   ```

2. Crear o editar la config global de Pi:

   ```bash
   nvim ~/.pi/agent/mcp.json
   ```

3. Pegar los servers necesarios en `mcpServers`.

4. Recargar Pi:

   ```text
   /reload
   ```

5. Verificar desde Pi:

   ```ts
   mcp({ })
   mcp({ connect: "lsp" })
   mcp({ server: "lsp" })
   ```

## Current servers

| Server | Install/runtime | Notes |
|---|---|---|
| `chrome-devtools` | `npx -y chrome-devtools-mcp@latest` | Browser/devtools automation. |
| `obsidian` | `npx obsidian-mcp <vault>` | Points to `/home/osmarg/Nextcloud/Documentos/obsidian-vault`. |
| `engram` | `engram mcp --tools=agent` | Requires `engram` binary available in `PATH`. |
| `context7` | `npx -y @upstash/context7-mcp` | Documentation lookup. Usually exposed as direct tools. |
| `exa` | HTTP `https://mcp.exa.ai/mcp` | Requires Exa auth/env already configured if needed. |
| `stitch` | `npx -y google-stitch-mcp proxy` | Requires `STITCH_API_KEY`. |
| `context-mode` | `context-mode` | Requires `context-mode` binary available in `PATH`. |
| `lsp` | `npx -y @theupsider/lsp-mcp@latest` | Language-server bridge for TS/Rust/Go/Python. |

## Example `~/.pi/agent/mcp.json`

```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": ["-y", "chrome-devtools-mcp@latest"],
      "directTools": false
    },
    "obsidian": {
      "command": "npx",
      "args": ["obsidian-mcp", "/home/osmarg/Nextcloud/Documentos/obsidian-vault"],
      "directTools": false
    },
    "engram": {
      "command": "engram",
      "args": ["mcp", "--tools=agent"],
      "directTools": true
    },
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"],
      "directTools": true
    },
    "exa": {
      "url": "https://mcp.exa.ai/mcp",
      "directTools": true
    },
    "stitch": {
      "command": "npx",
      "args": ["-y", "google-stitch-mcp", "proxy"],
      "env": {
        "STITCH_API_KEY": "${STITCH_API_KEY}"
      },
      "directTools": false
    },
    "context-mode": {
      "command": "context-mode",
      "directTools": false
    },
    "lsp": {
      "command": "npx",
      "args": ["-y", "@theupsider/lsp-mcp@latest"],
      "directTools": false
    }
  }
}
```

## LSP prerequisites

The LSP MCP runs where Pi runs. In this setup that means the Arch distrobox/container, not only the NixOS host.

Install or verify these binaries in the same shell/environment that launches Pi:

```bash
npm install -g typescript-language-server typescript pyright
go install golang.org/x/tools/gopls@latest
rustup component add rust-analyzer
```

Verify:

```bash
command -v typescript-language-server
command -v pyright-langserver
command -v rust-analyzer
command -v gopls
```

Initialize a project from Pi:

```ts
mcp({ connect: "lsp" })
mcp({
  tool: "lsp_lsp_init",
  args: '{"root":"/home/osmarg/Hobby/dotfiles","languages":["typescript","rust","go","python"]}'
})
mcp({ tool: "lsp_lsp_health", args: "{}" })
```

Expected health:

```text
typescript ready
rust       ready
go         ready
python     ready
```

## Dotfiles note

`~/.pi/agent/mcp.json` is currently treated as local-only in this dotfiles repo, so it is not synced by `orgm-dot`. Keep this guide as the rebuild source of truth unless the MCP config is intentionally promoted to a tracked host/shared file.
