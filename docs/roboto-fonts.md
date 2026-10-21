# Roboto compartida

`nixos/fonts.nix`, importado por `lib/mk-system.nix`, instala `pkgs.roboto`
en todos los hosts, roles y especializaciones. Es Roboto proporcional, no
RobotoMono Nerd Font. Incluye pesos estáticos reales y cursivas: Regular,
Italic, Medium, Medium Italic, Bold, Bold Italic, Light, Thin, Black y las
variantes Condensed incluidas en el paquete. No cambia fuentes predeterminadas.

El módulo compartido, su import y la regresión se versionan en este repositorio
para distribuir Roboto con la configuración de cada equipo. La instalación
a nivel sistema se aplica con el próximo `nh os switch` de cada equipo;
versionar o publicar estos cambios no ejecuta un rebuild ni un switch.

## Roboto Condensed

La misma dependencia `pkgs.roboto` también instala la familia **Roboto Condensed**
con ocho archivos TTF reales: Light, Light Italic, Regular, Italic, Medium,
Medium Italic, Bold y Bold Italic. Fontconfig debe encontrar esa familia, no
DejaVu Sans ni una Roboto normal comprimida o con cursiva simulada. No se añade
otro paquete con el mismo nombre de familia para evitar versiones duplicadas.

Esto se aplica declarativamente a todos los equipos, roles y modos mediante el
módulo compartido. No cambia `sans-serif`, monospace ni las fuentes de los temas.
Las aplicaciones Flatpak también deben verla a través de las fuentes del host.
Si un programa ya estaba abierto, puede ser necesario cerrarlo y abrirlo para
que actualice su lista de tipografías; no hace falta reiniciar el equipo.

## Disponibilidad inmediata

Se instalaron copias de los TTF en OrgM (`osmarg`) y Jarq (`jarq`), en
`~/.local/share/fonts/orgm-roboto-temporary`, con marcador `.orgm-managed`,
y se actualizó Fontconfig. No se hizo rebuild, switch ni reinicio.
Las aplicaciones ya abiertas pueden necesitar volver a abrirse para detectar
las nuevas familias.

Tras el switch que instale Roboto a nivel sistema, se pueden retirar esas
copias manuales para no conservar una versión antigua por usuario:

```sh
rm -rf -- "$HOME/.local/share/fonts/orgm-roboto-temporary"
fc-cache -f
fc-match 'Roboto:style=Medium Italic'
```

La instalación declarativa no depende de esas copias. No se eliminan
automáticamente archivos del usuario durante la activación.

Jarq utiliza el checkout de prueba
`~/Hobby/nixos-jarq-sway-trial/source`; también se añadieron allí el módulo
y su import, sin modificar el checkout remoto original antiguo.

## Comprobación de Roboto Condensed (2026-10-21)

- **OrgM:** ocho variantes detectadas por Fontconfig nativo y dentro de Artcraft
  Flatpak; ya estaban en la instalación Roboto existente. Caché actualizada.
- **Envy:** ocho variantes disponibles mediante el paquete del sistema; no se
  añadió una copia por usuario.
- **Lenovo:** faltaba la familia (resolvía DejaVu Sans). Se instalaron ocho TTF
  estáticos como copias reales en
  `~/.local/share/fonts/orgm-roboto-condensed-temporary`, con marcador
  `.orgm-managed` y manifiesto SHA256; `fc-cache` actualizado y estilos verificados.
- **Jarq:** sin ruta SSH a `10.0.0.98`; la instalación de Roboto anterior incluía
  Condensed, pero no se pudo comprobar de nuevo ni aplicar cambios allí.
- **Ero:** el nombre SSH no resuelve; disponibilidad actual no comprobada.

Todos los targets declarativos incluyen la misma familia mediante `nixos/fonts.nix`,
también en server/terminal y especializaciones. No se hizo switch ni reinicio.
La instalación por usuario de Lenovo permanece en disco entre reinicios; tras
activar el paquete de sistema puede retirarse **solo** ese directorio administrado
y regenerarse la caché, como las copias temporales de Roboto anteriores.

## Verificar

```sh
bash tests/roboto-fonts.bats.sh
fc-match 'Roboto:style=Bold Italic'
fc-match 'Roboto Condensed:style=Medium Italic'
fc-match 'Roboto Condensed:style=Bold Italic'
```

La regresión evalúa todos los hosts y modos, los roles server/terminal y los
metadatos de seis estilos Roboto y de los ocho Roboto Condensed. También prueba
Fontconfig aislado con solo los archivos del paquete, para que una copia previa
del usuario no esconda una dependencia faltante.
