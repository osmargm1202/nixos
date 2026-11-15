# Local development handoffs

For X13 work, read these before changing configuration or operating the laptop:

1. `nixos/hosts/x13/PENDING.md` — last verified state, recovery evidence and open work.
2. `odd/tasks/x13-bootstrap.md` — exact user requirements, task status and detailed evidence.
3. `nixos/hosts/x13/README.md` — installation, rebuilding and server recovery instructions.
4. `odd/tasks/x13-gnome-followups.md` — GNOME/webapp activation evidence and remaining first-login acceptance; distinguish tested configuration from physical runtime acceptance.

These files are local continuity notes, not fresh operational authorization. Verify
runtime state and Git status before resuming; preserve unrelated and unfinished edits.
Do not interpret a selected package or a passing evaluation as proof of installation
or working hardware. Do not put passwords, private keys or decrypted secrets in notes.

# Prefer prebuilt, compatible packages

The user prioritizes reliable binary substitution and short rebuilds on all hosts.
Prefer compatible packages from the locked stable nixpkgs release with artifacts
available from trusted, signed binary caches. Avoid selecting newer releases,
custom overlays, patches or package overrides that require substantial local
compilation merely to obtain a newer version. Check availability of the exact
derivation and its dependencies; a package name or version alone is not proof.

When a proposed package would require substantial compilation, first look for a
compatible prebuilt version or alternative and explain any unavoidable exception.
Explicitly requested experiments, such as testing Quickshell, may use custom
builds within that experiment's scope. Generating configuration files, launchers
and other small Nix derivations is expected and is not application compilation.
Keep signature verification enabled; never weaken cache trust to obtain a binary.
