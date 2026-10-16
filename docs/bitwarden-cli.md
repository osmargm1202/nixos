# Bitwarden CLI / Vaultwarden

The `bitwarden-cli` entry in `orgm.user.programs` installs `bw` and `bw-orgm`
for that user. It does not install a GUI, run at startup, provision SOPS secrets,
authenticate, or change an existing session during a rebuild. Jarq does not select
this integration. Run commands in a terminal as your normal user, not with sudo.

## Check the server first

```sh
bw-orgm init
bw-orgm status
```

`status` shows only lock state and server URL. `init` explicitly selects
`https://vw.or-gm.com` only for a genuinely fresh, unauthenticated profile whose
endpoint is unset or the default US Bitwarden cloud. A correctly configured profile is left
alone, including a logged-in/unlocked session. Another authenticated server or
custom configuration is refused without server changes. An existing logged-out
default/unset profile is also refused: the CLI exposes only its base URL and
cannot reveal custom per-service URL overrides safely. Review that situation manually;
do **not** logout, delete local data, or change server just to silence the check.
Do not run another server/configuration command concurrently with initialization.
The helper accepts only `init`, `status`, and help; all other work uses raw `bw`.
For a fresh installation run `init` before raw `bw` or `status`: the underlying
CLI creates a local profile even for `bw --version` or status queries. For
diagnostic/version probes use a disposable `BITWARDENCLI_APPDATA_DIR`, not the
real profile. If a profile already exists,
review its configuration and back it up before any manual server migration;
the helper deliberately cannot approve that migration for you. It never reads the
credential-containing `data.json` file, only checks whether it exists.

## Login and unlock manually

If `status` is `unauthenticated`, run `bw login` and answer its email, master
password and two-factor prompts interactively. If already `locked` or `unlocked`,
skip login. Never put passwords/session keys in command arguments, dotfiles,
shell history, Git, or Nix/SOPS configuration just to use this integration.

Then unlock into this terminal's environment (the password is prompted, not
stored). This also works for a new terminal when already logged in:

**Bash:**

```bash
if session="$(bw unlock --raw)"; then
  export BW_SESSION="$session"
fi
unset session
```

**Fish** (the Ryoku terminal may default to Fish):

```fish
set -l session (bw unlock --raw)
if test $status -eq 0
    set -gx BW_SESSION "$session"
end
set -e session
```

`BW_SESSION` is a secret unlock capability, held only in this terminal and its
children. Do not print it, use `set -x`, or add these values to persistent shell
configuration. Login/unlock are separate from the browser extension and desktop
app. This integration never logs you out or copies credentials between machines.

## Find an entry without printing all its secrets

```sh
bw sync
bw list items --search 'service name' | jq -r '.[] | [.name, .id] | @tsv'
```

Only names and IDs reach the terminal; full decrypted matching items still pass
through the pipe in memory. Do not enable tracing, redirect unfiltered output, or
run `bw list items` alone if you do not want passwords/notes in terminal scrollback.
Use an ID to disambiguate entries. Retrieve an individual password only when you
intend to reveal it, for example `bw get password ITEM_ID`; that prints the secret.
Prefer the browser extension for autofill. Clipboard use is optional, not part of
the wrapper; if using it, account for clipboard history/managers as well as expiry.

When finished, `bw lock` invalidates the unlock session but preserves login.
Then remove the environment variable: `unset BW_SESSION` in Bash or
`set -e BW_SESSION` in Fish. Do not use logout for routine locking.

Reference: [official Bitwarden CLI documentation](https://bitwarden.com/help/cli/)
(status, self-hosted server config, login/unlock and session semantics).
