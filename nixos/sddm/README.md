# SDDM · Qylock

Cada módulo de `qylock/` selecciona un tema y sus dependencias Qt 6 y multimedia.
Usan la revisión fijada en `sddm-qylock.nix`; no es necesario agregar otro input
al flake. Los módulos seleccionan el tema; la activación y el compositor del
greeter siguen siendo responsabilidad del perfil de escritorio.

| Tema | Módulo | Directorio upstream |
|---|---|---|
| Pixel · Emerald | `qylock/pixel-emerald.nix` | `pixel-emerald` |
| Enfield | `qylock/enfield.nix` | `enfield` |
| Forest | `qylock/forest.nix` | `forest` |
| Winter | `qylock/winter.nix` | `winter` |
| The Last of Us | `qylock/last-of-us.nix` | `last-of-us` |
| Girl · Coffee | `qylock/girl-coffee.nix` | `girl-coffee` |
| Wuthering Waves | `qylock/wuthering-waves.nix` | `wuwa` |
| osu! mania | `qylock/osu-mania.nix` | `osumania` |
| Ninja Gaiden | `qylock/ninja-gaiden.nix` | `ninja_gaiden` |

Importar **un solo** módulo desde la configuración del host, por ejemplo:

```nix
{
  imports = [ ../../sddm/qylock/forest.nix ];
}
```

También se puede seleccionar mediante las opciones compartidas:

```nix
{
  imports = [ ../../sddm/sddm-profile-qylock.nix ];
  orgm.sddm = {
    profile = "qylock";
    qylockTheme = "forest";
  };
}
```

Envy importa Forest en `nixos/hosts/envy/default.nix`; su única salida `envy`
usa Sway y el greeter Wayland. Gaming y server mantienen SDDM deshabilitado;
windows-vfio hereda Forest. Lenovo y ORGM conservan sus temas actuales.

El tema se toma directamente de la generación Nix. En Envy, la selección de
SDDM de RyoStore no sustituye esta elección declarativa. El lockscreen de la
sesión sigue administrado por su escritorio.

Validación de opciones, módulos y modos: `bash tests/sddm-profiles.bats.sh`.
La construcción de los paquetes comprueba que existen los recursos de cada
tema. La apariencia y el inicio de sesión requieren comprobar el greeter.

Fuente: [Darkkal44/qylock](https://github.com/Darkkal44/qylock/tree/22b92ae3318930c9e5b088b3c516b96d0fde6b15).
