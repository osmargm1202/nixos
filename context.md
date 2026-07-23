# Contexto de trabajo — NixOS (fecha: 2026-07-23)

## Hecho (resumen ejecutivo)
- Sí, el repositorio ya se remodulorizó en la fase base (thin-flake): constructor único + inventario explícito + flake delgado.
- Se mantuvieron **40 outputs** y aliases obligatorios.
- `flake.nix` ya no contiene la matriz manual completa de hosts/perfiles.
- `Home Manager` quedó integrado en NixOS (sin `homeConfigurations` standalone en esta fase).
- También se integraron 2 commits funcionales adicionales en `master`:
  - `76fc3a3 feat(terminal): add fast Zutty launcher`
  - `43e02d6 fix(i3): support xwinwrap-embedded video wallpaper`

## Qué se implementó en la migración thin-flake
- `docs/superpowers/specs/2026-07-22-nixos-repository-architecture-design.md`
  - define objetivo, restricciones y arquitectura objetivo completa.
- `docs/superpowers/plans/2026-07-22-nixos-baseline-thin-flake.md`
  - plan por fases T0/T1 (baseline + thin flake).
- `configurations.nix`
  - inventario explícito de configuraciones: 37 entradas + 3 aliases.
- `lib/mk-system.nix`
  - constructor `mkSystem` + wrappers compatibilidad (`mkHost`, `mkProfile`, `mkGeneralHost`, `mkServerHost`, `mkMinimalHost`, `mkTerminalHost`).
- `flake.nix`
  - usa `configurations.nix` + `mkSystem` para construir `nixosConfigurations`.
  - exporta `nixosConfigurations = builtConfigurations // configurationAliases`.
- Tests actualizados para evaluación real:
  - `tests/fixtures/nixos-configurations.txt`
  - `tests/flake-outputs.bats.sh`
  - `tests/configuration-inventory.bats.sh`
  - `tests/mk-system-library.bats.sh`
  - `tests/flake-architecture.bats.sh`
  - `tests/i3-profile.bats.sh`
  - `tests/binary-cache.bats.sh`

## Integraciones recientes (no parte central de la refactorización)
- `nixos/common.nix`: agregado wrapper `zutty-fast`.
- `dotfiles/config/profiles/...`: bindings de `Shift+Return` apuntan a `zutty-fast` (i3/Hyprland).
- `dotfiles/config/profiles/i3/.local/bin/i3-wallpaper`: ajuste compatibilidad `xwinwrap`.
- Tests i3 asociados actualizados.

## Estado actual del árbol
- Rama: `master`
- HEAD actual: `51e3cea chore(nixos): remove mate hosts and add codex/engram/rtk tooling`
- `git status`: limpio.
- Worktree auxiliar usado en el proceso fue removido.

## Pendiente por hacer
**Objetivo actual:** no están cerradas fases 2..6 del diseño.

- Fase 2: hosts explícitos por archivo de host.
- Fase 3: extraer `core` común y separar roles/sesiones.
- Fase 4: mover Home Manager a frontera clara (`modules/home`, `users/*/home.nix`).
- Fase 5: convertir profiles a composición pura de roles/sesiones.
- Fase 6: limpieza de inputs, checks adicionales, hardening funcional y mejoras operativas (secret manager, backups, journald, docker, etc.) en cambios separados.

## Validación pendiente (usuario)
- Evaluación completa de 40 outputs con `nix eval` en ciclo.
- `tests/binary-cache.bats.sh` y `bash tests/mate-profile.bats.sh`.
- `nix flake check --no-build -L` y validaciones dinámicas completas.
- Quedó explícitamente diferido por el usuario.

## Specs / Design relevantes
- `docs/superpowers/specs/2026-07-22-nixos-repository-architecture-design.md`
- `docs/superpowers/plans/2026-07-22-nixos-baseline-thin-flake.md`
- Otras specs relacionadas (no ejecutadas ahora):
  - `docs/superpowers/specs/2026-06-02-live-installer-nixos-dir-design.md`
  - `docs/superpowers/specs/2026-07-12-or-gm-nixos-server-migration-design.md`
  - `docs/superpowers/specs/2026-07-20-nixos-26-05-nwg-lua-runtime-ownership-design.md`

## Pistas de referencia rápida
- Mantener el contrato de outputs/aliases y no mezclar cambios funcionales con ruido de formato en commits.
- Prioridad: cambios estructurales en bloques limpios (fase por fase), commits separados.
