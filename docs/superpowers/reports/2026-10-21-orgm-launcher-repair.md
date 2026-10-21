# Restaurar Win+Space en OrgM — 2026-10-21

## Goal
Corregir el launcher de aplicaciones sin cambiar el perfil scroll ni los atajos.

## Instructions
Aplicar la corrección y comprobarla antes de pedir pruebas al usuario. Sin reinicios, root, commit/push o cambios de autenticación.

## Discoveries
- Regresión del último cambio: hypr-app-launcher invocaba orgm-rofi, pero ~/.local/bin/orgm-rofi no existía.
- El helper estaba bajo programs/rofi, programa NO seleccionado en los contextos reales. El manifiesto de aplicación rofi no activa automáticamente esa capa de programas.
- Los tests anteriores ejecutaban/copìaban el helper desde la fuente y no comprobaban su entrega mediante orgm-dot.

## Accomplished
- Movido el mismo ejecutable a profiles/wayland, capa compartida que siempre se carga en Sway/Hyprland. Propietario del archivo sigue siendo la aplicación rofi.
- Nueva prueba real de despliegue: contextos sin programa rofi, pull de aplicaciones y ejecución del launcher instalado para OrgM/Envy/Jarq.3fallos RED y3casos GREEN.
- Actualizado checkout canónico con guardas y aplicado pull rofi en OrgM con respaldo.
- Verificado binding Win+Space activo y programa configurado; el comando instalado abrió el Rofi drun REAL en Hyprland actual. Cerrado solamente el proceso de prueba propio; sin inyectar teclas ni capturar ventanas.
- Envy tenía el mismo helper ausente: aplicado desde copia nueva del staging anterior, conservando archivos ajenos que un pull completo habría eliminado. Rofi real parsea el tema correctamente.
- Pasaron estilo, sesiones nativas Rofi/OSK y menús Sway, regresiones Firefox/pestañas/Rofi y nix flake check --impure --no-build. Sin afirmar cobertura física de todos los dispositivos.

## Next Steps
- El usuario ya puede probar Win+Space en OrgM; no necesita reiniciar ni recargar Hyprland.
- La activación administrativa SDDM/bloqueo anterior sigue pendiente e independiente de esta reparación.
- Para esa activación en Envy, usar/reconstruir la fuente corregida `/home/osmarg/Hobby/nixos-launcher-repair-20261021-2d4qid56/source`, no el staging anterior que omitía el helper. No se hizo switch en esta sesión.

## Relevant Files
- `dotfiles/config/profiles/wayland/.local/bin/orgm-rofi` — ubicación efectiva corregida.
- `dotfiles/config/programs/rofi/.local/bin/orgm-rofi` — retirada ubicación que nunca se seleccionaba.
- `tests/launcher-deployment.test.py` — regresión de despliegue y ejecución real por3contextos.
- `tests/menu-style-parity.test.py` — ruta nueva y entorno XDG privado.
- `tests/osk-session.test.py`, `tests/sway-menus-session.test.py` — referencias nativas corregidas.

## Key Learnings:
1. Registrar una ruta en un manifiesto no selecciona su capa programs; helpers comunes Wayland deben estar en profiles/wayland.
2. La prueba debe desplegar con el contexto real y ejecutar el archivo instalado, no copiar manualmente una dependencia que producción omite.
