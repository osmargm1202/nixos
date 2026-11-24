# Webapps de osmarg

Firefox abre los enlaces y archivos HTML. En X13 y ORGM, las webapps se
abren desde el menú con Chromium en modo aplicación. Cada una guarda sus
cookies y sesión en `~/.local/share/chromium-webapps/<profile-id>`, separado
del perfil de Chromium que pueden usar los agentes para tareas headless.

| Menu application | URL | Profile ID |
| --- | --- | --- |
| SLC Daily | https://daily.slci.stream | `slc-daily` |
| SLC Vill Docs | https://vill-docs.slci.stream | `slc-vill-docs` |
| ORGM Administration | https://adm.or-gm.com | `orgm-adm` |
| ORGM Automation | https://automation.or-gm.com | `orgm-automation` |
| ORGM Code | https://code.or-gm.com | `orgm-code` |
| Facturador Gratuito DGII | https://fg.dgii.gov.do/ecf/PortalFG/login | `dgii-facturador` |
| Cloud ORGM | https://cloud.or-gm.com/ | `cloud-orgm` (existing) |

ORGM Code, ORGM Automation y Facturador Gratuito DGII se seleccionan en
`nixos/users/osmarg.nix`. SLC Daily, SLC Vill Docs y ORGM Administration se
seleccionan en `nixos/hosts/x13/webapps.nix`.

GNOME asocia cada ventana Wayland a su entrada de escritorio. En i3 cada
ventana tiene su propio `WM_CLASS`. La activación actualiza los favoritos
de Brave Origin en GNOME y nwg-dock, con copias en
`~/.local/state/orgm-chromium/`. Cada webapp reutiliza su antiguo perfil de
Chromium si existe. Para recuperar una sesión que solo estaba en Brave Origin
o GNOME Web, vuelve a iniciar sesión en la webapp de Chromium.

## Verificación

```bash
python3 tests/x13-webapps.test.py
bash tests/chromium-webapps.bats.sh
```

Las pruebas evalúan las entradas de menú, la selección por usuario, las
identidades de ventana y los directorios de los perfiles. Después de activar
el sistema, abre las webapps desde el menú para comprobar la agrupación de
ventanas y el acceso a cada servicio.
