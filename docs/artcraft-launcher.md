# ArtCraft Launcher

El launcher es parte de la base compartida de escritorios con Flatpak en
`nixos/apps/flatpak.nix`, no de las listas personales de Osmarg o Jarq.
Está disponible para todos los usuarios, incluso si la lista personal de
Flatpaks está vacía. No se agrega a servidores ni perfiles de terminal ni se
inicia automáticamente.

## Instalación y actualizaciones

Nix solo hace la primera instalación. El servicio de usuario
`orgm-artcraft-launcher-bootstrap` corre al iniciar sesión y, si el launcher no
está instalado (ni `--user` ni `--system`), instala el bundle oficial de GitHub
(0.19.2 por defecto, x86_64, verificado con SHA-256 mediante `pkgs.fetchurl`)
con `flatpak install --user`. Si ya existe no hace nada, sea cual sea la
versión. Si falla (por ejemplo, sin red al iniciar sesión), reintenta cada dos
minutos.

Desde ahí el launcher se mantiene solo: **Update and restart** actualiza el
launcher y él mismo actualiza las apps de la suite que instaló, en el mismo
formato y verificando los checksums del release. No hay que desinstalar nada.

El launcher ya no está en `services.flatpak.packages`: nix-flatpak volvería a
instalar la versión fijada encima de la actualizada. En los equipos donde
nix-flatpak lo había instalado a nivel de sistema, la siguiente activación lo
desinstala (sin borrar `~/.var/app`) y el servicio de usuario lo instala de
nuevo para el usuario, que puede actualizarlo sin pedir contraseña.

`orgm.artcraft.launcher.version` y `orgm.artcraft.launcher.sha256` solo eligen
el bundle de esa primera instalación. El usuario `hm` usa 0.8.1; el launcher
lo actualizará igual. Su selección personal también incluye CADCraft 0.13.0.
El perfil ligero omite Remmina mediante `orgm.flatpak.remmina.enable = false`.

Después de instalar los bundles, `orgm-artcraft-integrations` completa las
asociaciones, el acceso de CADCraft a las fuentes y su entrada de apertura
reutilizable.

Las aplicaciones de la suite que cada usuario instale y sus datos no se
eliminan; se mantiene desactivada la limpieza de aplicaciones no administradas
por Nix. Los permisos del bundle oficial incluyen acceso al directorio personal
y `org.freedesktop.Flatpak` para instalar/abrir aplicaciones fuera del sandbox;
no se agregan permisos adicionales.

## Actualizar a mano un bundle

Si alguna vez hace falta, se instala encima sin desinstalar y se conservan los
datos:

```
flatpak install --user --reinstall --noninteractive artcraft-launcher-<ver>-linux-x86_64.flatpak
```

## Cambiar el bundle de primera instalación

1. Consultar los [releases oficiales](https://github.com/storytold/craft-launcher/releases).
2. Tomar el hash del bundle en `SHA256SUMS.txt` del release.
3. Cambiar los valores por defecto de `orgm.artcraft.launcher` en el módulo.
4. Ejecutar `python3 tests/artcraft-launcher.test.py`.

Solo afecta a equipos o usuarios nuevos; los que ya lo tienen no cambian.
