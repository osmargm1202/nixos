# Migración aplicada: hosts, Ryoku y Bitwarden CLI

## Alcance
- Trabajo aislado en `.worktrees/envy-normal`, rama `feat/envy-normal`.
- Salidas públicas: `envy`, `lenovo`, `orgm` con Ryoku; `ero`, `jarq` con i3.
- Ryoku conserva sus sesiones Hyprland/Niri en el mismo sistema. Configuraciones
  históricas conservadas internamente; no se fusionaron otros escritorios.
- Modos internos/defaults/GPU/Compose preservados y comparados exactamente.
  No se implementan todavía los modos avanzados de Envy.
- Cuatro cambios previos del usuario y el borrador Windows siguen preservados;
  se conservaron fuera de commits durante la implementación. Posteriormente el
  usuario solicitó commit/push completo; el cierre se registra en
  `2026-10-15-envy-audio-volume.md`, sin merge automático a master.

## Activado y verificado en Envy
- Configuración nueva enlazada como generación5, sin reinicio de equipo ni SDDM.
  La unidad display-manager era idéntica y conservó PID/fecha de inicio.
- Menú de arranque:1segundo. Hyprland NumLock activo. SDDM `Numlock=on` declarado
  y desplegado para su próximo arranque; aceptación visual del greeter pendiente.
- `bw` y `bw-orgm` disponibles para Osmarg. No se inició sesión, desbloqueó,
  consultó bóveda ni copiaron credenciales. Servidor previsto: `https://vw.or-gm.com`.
  Ejecutar `bw-orgm init` antes de cualquier otro comando de bw en perfil nuevo;
  incluso `bw --version` crea estado. Uso completo en `docs/bitwarden-cli.md`.
- Arranque compartido nativo de Ryoku: Syncthing/Tailscale preservados y activos.
  Las opciones personales proceden de `orgm.user.autostart`, no del host.
  En Envy existía selección vacía explícita: se conserva y solo se reinsertan
  los trays esenciales. Nextcloud/Discord/Steam pueden elegirse en Hub→Session;
  no se fuerza su ejecución. Sunshine conserva su propia unidad.
- `Super+H`:Stash; `Super+K`:ayuda nativa. Migración conserva otros datos del Hub
  y preferencias previas; backups/marker0600. Configuración Hyprland sin errores.
- El PATH del proceso hypridle real ya resuelve el hyprctl del compositor elegido
  y permite consulta WM. Sin pruebas que apaguen pantallas: estabilidad física
  al despertar, HDMI y contenido recortado de LG siguen pendientes.

## Aviso de activación, aceptado previamente
El cambio de sistema y los enlaces/paquetes/migración de Home Manager sí se
aplicaron. El switch terminó con código4 porque la última etapa `sops-nix`
no dispone de la identidad privada; Home Manager quedó marcado como fallido.
No se cambió la política SOPS ni se copiaron claves para ocultar ese aviso.
No afirmar activación global limpia. Servicios de Ryoku, Syncthing y Tailscale
comprobados activos; falta de identidad sigue siendo decisión del usuario.

## Verificación y límites
- Revisión independiente por tarea y global:sin hallazgos Critical/Important.
- Compilación completa de los cinco hosts aprobada: Envy, ORGM, Lenovo, Ero y
  Jarq. Solo Envy se activó; los otros cuatro quedaron sin desplegar.
- Contratos de inventario/paridad, startup, Bitwarden, NumLock y PATH aprobados.
  Pruebas de los dos proveedores fijados,10migraciones,187atajos upstream y119
  personales, y validación real de Hyprland aprobadas.
- Pruebas históricas ampliadas:34/38 aprobadas;4fallos preexistentes documentados
  (helper compartido inexistente, xclip de Cinnamon, Sunshine histórico de Jarq,
  aislamiento de paquetes de Jarq). La prueba Chromium se adaptó y pasa;
  no se declara verde global ni flakecheck completo.
- Huella de Envy06cb:00c9:sin soporte normal confirmado; no instalar controlador
  experimental ni cambiar PAM. Optane/discos y credenciales quedan intactos.

## Próximos pasos
- Elegir aplicaciones opcionales en Hub→Session según preferencia del usuario.
- Login manual de Bitwarden y de las demás aplicaciones, sin copiar sesiones.
- Validar físicamente próximo greeter/resume y retomar LG solo cuando se solicite.
- Planificar por separado huella compatible, backup externo, Optane y modos
  avanzados de Envy. Otros hosts requieren despliegue individual acordado.
