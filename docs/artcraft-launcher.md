# ArtCraft Launcher

El launcher es parte de la base compartida de escritorios con Flatpak en
`nixos/apps/flatpak.nix`, no de las listas personales de Osmarg o Jarq.
Se instala a nivel de sistema para estar disponible para todos los usuarios,
incluso si la lista personal de Flatpaks está vacía. No se agrega a servidores
ni perfiles de terminal ni se inicia automáticamente.

Se descarga el bundle oficial de GitHub (actualmente 0.5.1, x86_64), verificado
con SHA-256 mediante `pkgs.fetchurl`, y se instala con el servicio existente
`flatpak-managed-install` después de activar la configuración NixOS.
No basta agregar el ID a Flathub: upstream distribuye el archivo `.flatpak`.

Solo se declara el launcher. Las aplicaciones de la suite que cada usuario
instale y sus datos no se eliminan; se mantiene desactivada la limpieza de
aplicaciones no administradas por Nix. Los permisos del bundle oficial incluyen
acceso al directorio personal y `org.freedesktop.Flatpak` para instalar/abrir
aplicaciones fuera del sandbox; no se agregan permisos adicionales.

## Actualizar la versión declarada

1. Consultar los [releases oficiales](https://github.com/storytold/craft-launcher/releases).
2. Descargar el bundle y comprobar su hash contra `SHA256SUMS.txt` del release.
3. Cambiar `artcraftVersion` y `artcraftSha256` en el módulo compartido.
4. Ejecutar `rtk proxy python3 tests/artcraft-launcher.test.py` y activar la
   configuración mediante el procedimiento normal del equipo.

Los bundles no tienen un repositorio de actualizaciones: `flatpak update` no
descubre nuevos releases de GitHub. Este cambio no agrega un actualizador
automático ni modifica el comportamiento de actualización de otros Flatpaks.
