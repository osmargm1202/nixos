# Steam: conexión Xwayland recuperada

## Goal
Corregir `Unable to open a connection to X` sin reiniciar el escritorio,
cerrar aplicaciones ajenas ni debilitar los controles de acceso.

## Discoveries
- DISPLAY era correcto (`:0`) en el cliente, su contenedor y el gestor de usuario.
  Xwayland seguía vivo como PID2734, pero faltaba `/tmp/.X11-unix/X0`.
  Su listener alternativo `X0_` seguía operativo; no había listener abstracto :0.
- La llamada nativa `XOpenDisplay(:0)` fallaba, por tanto el fallo no era
  exclusivamente del sandbox de Steam ni falta de un paquete gráfico.
- La marca temporal del directorio X11 coincide con nuestras últimas pruebas
  de movimiento en compositores privados. Once fixtures Wayland-only dejaban
  habilitado Xwayland y compartían `/tmp/.X11-unix` con el escritorio. Esa
  combinación puede colisionar con el display del padre, cuyo Xwayland no
  publica un socket abstracto. Se trata como un defecto de aislamiento de las
  pruebas, no como un fallo de configuración de Steam.

## Accomplished
- Comprobados UID y tipo del socket superviviente, PID del lock, proceso y FD
  del servidor. Se creó únicamente el enlace ausente `X0 -> X0_`; nunca se
  reemplazó un socket existente. `XOpenDisplay(:0)` pasó después de la reparación.
- También pasó XOpenDisplay dentro de un FHS nuevo mediante steam-run.
- El updater fallido ya había terminado; no se mató ningún proceso. Steam se
  inició normalmente, sin URI de juego, mediante la unidad transitoria de usuario
  `orgm-steam-recovery-20261022.service`. Steamwebhelper arranca y Hyprland
  confirma dos ventanas Steam mapeadas. Sin introducir credenciales ni abrir un juego.
- La nueva regresión AST falló inicialmente enumerando once fixtures inseguras.
  Se añadió `xwayland disable` solo a las configuraciones de esas pruebas.
  El contrato ahora confirma quince configuraciones privadas protegidas.
  **Xwayland continúa habilitado en los escritorios reales y para Steam.**

## Verification
- Native XOpenDisplay y mismo sondeo dentro de un FHS nuevo: PASS.
- Interfaz Steam mapeada y unidad transitoria activa: verificado.
- Contrato `tests/wayland-session-isolation.test.py`: quince configs PASS.
- Contrato de movimiento y whitespace: PASS.
- Ocho integraciones privadas pasan después del arreglo: movimiento, Caffeine,
  widgets, escritorio Sway, gaming, menús, wallpapers y reglas flotantes VLC.
  En cada resultado y al terminar se verificaron iguales los inodos/tipos del
  enlace X0, listener X0_ y lock X0 del padre. Steam permaneció abierto.
- Las otras tres fixtures editadas (lock opt-in y dos pruebas GTK opt-in) se
  comprobaron con el contrato AST/sintaxis; no se repiten sus integraciones aquí.
  No se afirma verde toda la suite del repositorio.

## Next Steps
La sesión actual conserva el enlace de recuperación al listener del mismo
Xwayland. Una sesión gráfica nueva volverá a crear sus sockets normales; no
se modifica la configuración permanente de Steam ni se requiere reiniciar ahora.
El usuario puede comprobar su uso habitual de Steam. No se probó iniciar sesión,
descargar/ejecutar juegos o cambiar ajustes de cuenta.

## Relevant Files
- `tests/wayland-session-isolation.test.py` — guard AST de fixtures headless.
- Once pruebas de sesión Wayland-only, incluida `window-move-session.test.py`
  — Xwayland innecesario deshabilitado solo en su config privada.
- `/tmp/.X11-unix/X0` — reparación runtime, fuera del repositorio.
- `.superpowers/sdd/2026-10-22-steam-xwayland/` — diagnósticos y resultados locales.

## Key Learnings:
1. HOME y XDG_RUNTIME_DIR privados no aíslan los sockets X11 de /tmp.
2. Las pruebas Wayland-only deben deshabilitar su Xwayland; las pruebas X11
   necesitan aislamiento explícito de sockets y no deben reutilizar los del padre.

## Publicación solicitada
El usuario solicitó commit/push de todo lo pendiente. Antes de publicar se
repitieron las ocho integraciones privadas, el guard de quince configs, los
contratos de movimiento/dispatch/paridad/ScrollOverview y el chequeo completo
del flake (`NIXPKGS_ALLOW_UNFREE=1 nix flake check --impure --no-build .`): pasan.
Los sockets X11 del padre se conservaron durante las integraciones. No se
repitió ni se declara verde la suite general con sus fallos previos documentados.
