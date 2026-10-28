# Aplicaciones de terminal compartidas

Todos los sistemas creados por `lib/mk-system.nix` incluyen de forma predeterminada
`rmatrix`, `peaclock` y `cava`. La instalación no depende del usuario ni del
escritorio: también se conserva en los perfiles terminal, servidor y multimedia.
Los tres disponen de accesos de aplicaciones con `Terminal=true`; no se agregan
autoinicios, servicios ni compositores.

- `rmatrix`: lluvia digital, con el binario oficial fijado por SHA-256.
- `peaclock`: reloj, temporizador y cronómetro nativo.
- `cava`: visualizador del audio de salida, usando el monitor del dispositivo
  predeterminado mediante PulseAudio o la compatibilidad Pulse de PipeWire.

CAVA utiliza 30 FPS, salida `noncurses` y reposo tras cinco segundos de silencio.
Si existe `$XDG_CONFIG_HOME/cava/config` (normalmente `~/.config/cava/config`),
respeta esa configuración personal. También respeta `cava -p ARCHIVO`.

El paquete común se construye en el equipo principal y se transfiere a la
ThinkPad; la laptop no compila estas aplicaciones. Los hosts que todavía no
hayan reconstruido el sistema pueden instalar el mismo paquete en su perfil
Nix de usuario. Para desactivar solo esta selección compartida en otro equipo,
usar `orgm.terminalVisuals.enable = false`.

Validación: `python3 tests/terminal-visuals.test.py`. Se probaron las tres
aplicaciones en terminales privadas de la ThinkPad y la respuesta FFT de CAVA
con PCM sintético por FIFO, sin reproducir sonido en los altavoces.
