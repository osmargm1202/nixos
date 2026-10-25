# Jarq — corrección persistente VA-API Intel

## Problema y elección
El RDD de Firefox estaba decodificando vídeo en CPU. La prueba real `vainfo --display drm --device /dev/dri/renderD128` fallaba porque no existía backend iHD/i965. GPU PCI8086:1616, Broadwell. Mesa y el nodo DRM ya estaban disponibles: no era necesario tocar el kernel, input o sandbox.

Se probó **intel-media-driver26.1.6 (iHD)**, mantenido y compatible con Broadwell según [Intel](https://github.com/intel/media-driver#supported-platforms). Funcionó en el dispositivo real; no se instaló el controlador archivado i965 ni se forzó un nombre de driver. Capacidades verificadas en Jarq: H.264, VP8 y formatos antiguos; no AV1/VP9/HEVC hardware. Instalar drivers no añade capacidades que no tiene la GPU.

## Cambios y despliegue
- `nixos/hosts/jarq/base.nix`: `hardware.graphics.extraPackages` y `extraPackages32` incluyen `intel-media-driver`64/32. Limitado al host, sin cambiar otros Intel, preferencias de Firefox o sandbox.
- Mismo bloque añadido selectivamente a la fuente Sway ACTUAL de Jarq (`/home/jarq/Hobby/nixos-tablet-20261020/source/nixos/hosts/jarq/base.nix`). Conservados sus imports Wi-Fi, política SWIOTLB/iommu=soft y demás ajustes diferentes del checkout canónico. Backup `/home/jarq/.local/state/orgm-vaapi/backups/20261023T060152Z/base.nix`.
- Construido target `jarq-sway` de esa fuente, **no el Jarq/i3 canónico**. Diff de closures: solamente graphics/graphics-drivers, intel-media-driver/gmmlib/libva. Simulación dry-activate: solo tmpfiles-resetup a reiniciar. Aplicación switch terminó correctamente; no se ordenó cerrar/reiniciar Firefox, Sway, display manager ni el equipo.
- Sistema activo y perfil persistente: generación22, `/nix/store/7vlas6c7piykcs6nxfjxhm2lfyjxpia4-nixos-system-jarq-sway`. Generación21 anterior `/nix/store/args6pzvicwngvk7frxv5nv199znmd7q-nixos-system-jarq-sway` retenida para rollback. Sin overlays ad hoc en /run, unidades bootstrap ni escritura al Nix store.

## Verificación
1. Regresión de configuración RED sin drivers; GREEN con64/32 y sin `MOZ_DISABLE_RDD_SANDBOX`. Proyección de hosts públicos evaluada.
2. `vainfo` real exitoso primero con backend explícito de prueba y, después del switch, **sin ninguna variable LIBVA especial**, cargando `/run/opengl-driver/lib/dri/iHD_drv_video.so`. Driver32 también existe.
3. FFmpeg real decodificó120frames de MP4 H.264 propio720p/30fps con VA-API y descarga de superficies hardware;0errores, exit0.
4. Firefox real, perfil desechable, servidor local de vídeo propio y Sway GLES2 headless privado sobre la GPU real: VA-API inicializado, `IsHardwareAccelerated=true`, al menos90frames hardware y5muestras de tiempo/frames avanzando; sin indicador de fallback software. Prueba final posterior al switch **sin override de driver**: PASS, evidencia `/tmp/jarq-vaapi-private-vq411g07`.
5. Sin input ni captura del escritorio real; no se leyó contenido del perfil del usuario. Solo se inspeccionaron preferencias gráficas específicas (sin overrides encontrados). Se terminaron exclusivamente los procesos de fixture propios. La comprobación posterior encontró que el Firefox original ya no estaba y Chromium estaba abierto; no hay eventos OOM/segfault observados. No se atribuye a esta corrección una reducción CPU antes/después de ese cambio de aplicación.
6. Sway original PID5216 y servicios CC/OSK/Waybar/VNC/túnel siguen activos. `git diff --check` limpio. Sin commit/push.
7. Revisión independiente: detectó que inicialización VA-API no bastaba para demostrar decodificación sostenida. Corregido el fixture con contadores numéricos, salida real de frames y rechazo de fallback; nueva revisión sin importantes y prueba fuerte ejecutada con éxito.

## Uso y límites
No necesita reiniciar el equipo. Si Firefox estaba abierto antes de instalar el driver, cerrarlo/abrirlo normalmente cuando sea conveniente permite renovar la detección de códecs. H.264 puede aprovechar la GPU; AV1/VP9 seguirán utilizando CPU en este hardware. Se preguntó al usuario si quiere favorecer H.264 con su posible límite de calidad; **sin respuesta no se modifican formatos, extensiones ni preferencias**. No se promete reducción CPU idéntica para cualquier vídeo.

## Rollback
Si fuera necesario: seleccionar generación21 del perfil de sistema y ejecutar su `bin/switch-to-configuration switch` con privilegios administrativos. Restaurar el backup exacto del bloque del host en la fuente activa, sin reemplazar archivos Wi-Fi/nativeSway por los del checkout canónico. No se modificaron archivos privados o claves SSH.
