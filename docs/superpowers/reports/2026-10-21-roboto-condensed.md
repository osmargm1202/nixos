# Roboto Condensed en todos los sistemas — 2026-10-21

## Goal
Ofrecer Roboto Condensed real para que las aplicaciones reconozcan y representen correctamente sus variantes, sin cambiar las fuentes predeterminadas.

## Instructions
Reutilizar la instalación compartida Roboto existente; instalar inmediatamente donde falte y haya conexión. No hacer switch, reiniciar, pedir contraseñas ni modificar preferencias de tipografía. Mantener cambios pendientes ajenos.

## Discoveries
- El paquete fijado `pkgs.roboto3.015` ya incluye Roboto y ocho archivos estáticos Roboto Condensed: Light/Regular/Medium/Bold, cada uno con su cursiva real.
- El módulo `nixos/fonts.nix` ya instala el paquete en todos los hosts, roles y especializaciones. No hace falta añadir otra versión de la misma familia.
- OrgM tenía las ocho variantes por usuario y Envy las tiene en su paquete del sistema. Lenovo resolvía incorrectamente DejaVu Sans porque le faltaba la familia.
- Artcraft Flatpak ve las fuentes del usuario a través de `/run/host/user-fonts`; se comprobaron las ocho variantes dentro del sandbox.

## Accomplished
- Lenovo: instaladas ocho copias TTF reales en `~/.local/share/fonts/orgm-roboto-condensed-temporary`; marcador administrado y manifiesto SHA256, caché actualizada y8coincidencias de familia/estilo/archivo correctas. Persisten entre reinicios, sin depender de symlinks del store.
- OrgM: caché actualizada;8coincidencias nativas y8en Artcraft Flatpak verificadas, sin duplicar la instalación anterior.
- Envy:8coincidencias con fuentes de sistema verificadas; no se añadió copia redundante.
- Cobertura declarativa de todos los hosts/roles/modos confirmada. Comentarios y documentación explicitan Condensed; selección del paquete y defaults sin cambios.
- Regresión ampliada:6Roboto+8RobotoCondensed, metadatos reales y Fontconfig aislado que debe resolver cada archivo/estilo exacto. Pasó en worktree y checkout canónico; era funcionalidad ya proporcionada, por lo que la nueva cobertura estaba verde antes de cambiar comentarios/docs, sin fingir un ciclo RED.
- `nix flake check --impure --no-build` pasó; solo advertencia existente de renombrado nixfmt. Bash syntax y diff-check limpios. `sans-serif` continúa DejaVu Sans en OrgM/Lenovo.
- Aplicados tres archivos al checkout canónico con guardas SHA256; sin root, switch, reinicio, cambios de launcher/tablet/lock, commit ni push.

## Next Steps
- Cerrar y volver a abrir las aplicaciones que conservan una lista antigua de fuentes; no se cerró ningún programa automáticamente.
- Jarq: SSH a10.0.0.98 sin ruta. Ero: nombre no resuelve. Ninguno figura como peer Tailscale conocido; no se pudo verificar/aplicar en sus sesiones actuales. La configuración declarativa sí los incluye; Jarq tenía una copia Roboto anterior que incluía Condensed, sin afirmación de estado actual.
- Al actualizar cada sistema con su próximo switch normal se mantiene la dependencia compartida. En Lenovo podrá retirarse solo el directorio temporal administrado después de confirmar la fuente de sistema.

## Relevant Files
- `nixos/fonts.nix` — selección compartida existente, comentarios de Roboto Condensed.
- `tests/roboto-fonts.bats.sh` — matriz NixOS completa y14metadatos/coincidencias de fuentes aisladas.
- `docs/roboto-fonts.md` — familias, pesos, comprobación, disponibilidad por equipo y copias temporales.
- `~/.local/share/fonts/orgm-roboto-condensed-temporary` en Lenovo —8TTF, marcador y manifiesto.

## Key Learnings:
1. El paquete Roboto existente incluye la familia Roboto Condensed; instalar otra versión duplicaría nombres de familia.
2. Hay que verificar familia, estilo y archivo con Fontconfig, no aceptar silenciosamente una fuente fallback.
