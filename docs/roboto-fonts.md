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

## Verificar

```sh
bash tests/roboto-fonts.bats.sh
fc-match 'Roboto:style=Bold Italic'
```

La regresión evalúa todos los hosts y modos, los roles server/terminal y los
metadatos de los seis estilos principales de los archivos TTF del paquete.
