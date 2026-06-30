package dotcli

const Usage = `Usage:
  orgm-dot diff [--host HOST] [--no-color|--porcelain]
  orgm-dot sync [PATH] [--host HOST] [--dry-run]
  orgm-dot daemon [--host HOST]
  orgm-dot add PATH (--shared|--host HOST)
  orgm-dot remove PATH (--shared|--host HOST)
  orgm-dot install
  orgm-dot status [--host HOST]

Legacy command flags like --diff and --sync still work, but the fast form
without -- is preferred.

Sync:
  PATH is optional and limits sync to one managed file or subtree.

Host:
  diff, sync, daemon, and status default to the system hostname.
  Use --host HOST to override.

Environment:
  ORGM_DOT_CONFIG=/path/to/dotfiles.json
`
