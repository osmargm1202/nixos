# Sincronización de Nextcloud sin escritorio

El Lenovo dispone de `nextcloud-server.service` y `nextcloud-server.timer`
para los usuarios que seleccionan el programa `nextcloud`. La primera ejecución
se programa un minuto después del arranque; las siguientes, cinco minutos
después de terminar la anterior. No necesita una sesión gráfica ni una sesión
interactiva abierta.

El servicio comprueba que `/etc/orgm/desktop-profile` contiene `server` y que
el cliente gráfico no está ejecutándose. Utiliza `~/Nextcloud` y la lista
existente `~/.config/Nextcloud/sync-exclude.lst`. La sincronización es
bidireccional: también propaga cambios y eliminaciones.

El cliente reutiliza el historial `.sync_*.db` de la misma cuenta, servidor y
carpeta remota, incluidas las exclusiones de carpetas de la sincronización
selectiva. Durante la ejecución comprueba cada cinco segundos si cambió el
perfil o se abrió el cliente gráfico; en ese caso detiene solo su propio
proceso de sincronización.

Las credenciales se guardan únicamente en
`~/.config/nextcloud-server.env`, propiedad del usuario y con permisos `0600`:

```ini
NC_URL="https://tu-servidor-nextcloud"
NC_USER="tu-usuario"
NC_PASSWORD="contraseña-de-aplicación"
```

Usar una contraseña de aplicación o la autorización oficial Login Flow v2.
No guardar credenciales en Git ni en el almacén de Nix. El archivo no se
genera con Nix y no depende de desbloquear un llavero gráfico.

```bash
systemctl --user status nextcloud-server.timer nextcloud-server.service
systemctl --user list-timers nextcloud-server.timer
journalctl --user -u nextcloud-server.service -n 30
systemctl --user start nextcloud-server.service
```

Para desactivar únicamente esta sincronización:

```bash
systemctl --user stop nextcloud-server.timer
```

El temporizador espera a que finalice cada ejecución; no acumula procesos.
Un fallo queda registrado y el temporizador vuelve a intentarlo. La ejecución
tiene prioridad reducida y un límite de seis horas.

La instalación inicial sin reconstruir NixOS enlaza las dos unidades desde
`~/.local/state/nextcloud-server/units`, que mantiene una raíz de GC para su
compilación de Nix. La siguiente activación normal de NixOS retira únicamente
esos enlaces de arranque y deja las unidades bajo administración declarativa.
No hace falta una reconstrucción global para poner en marcha la instalación
inicial.

Documentación oficial:

- https://docs.nextcloud.com/server/stable/user_manual/en/desktop/commandline.html
- https://docs.nextcloud.com/server/stable/developer_manual/client_apis/LoginFlow/index.html#login-flow-v2
