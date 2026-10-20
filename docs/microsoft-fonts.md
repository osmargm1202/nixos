# Fuentes de Microsoft

La base de escritorio compartida `nixos/common.nix` instala estos paquetes en
Envy, Lenovo, ORGM, Ero y Jarq. Los modos de arranque que heredan esa base
conservan los mismos paquetes.

| Paquete | Familias verificadas |
| --- | --- |
| `corefonts` | Arial, Arial Black, Tahoma, Times New Roman, Courier New, Georgia, Verdana, Trebuchet MS, Comic Sans MS, Impact, Andale Mono y Webdings |
| `vista-fonts` | Calibri, Cambria, Cambria Math, Candara, Consolas, Constantia y Corbel |
| `microsoft-office-fonts` (paquete local) | Century Gothic y Arial Narrow, ambas en regular, negrita, cursiva y negrita cursiva |

Las fuentes se añaden al catálogo de Fontconfig para que puedan seleccionarse
en las aplicaciones. No se modifica la tipografía elegida para el escritorio.

Para instalarlas en cada equipo, reconstruir su configuración. Por ejemplo,
en Envy:

```bash
nh os switch /home/osmarg/Hobby/nixos -H envy
```

Después, volver a abrir las aplicaciones que ya estaban ejecutándose.
La existencia de una familia se comprueba con `fc-list`; `fc-match` por sí solo
también puede devolver una sustitución cuando la fuente solicitada no existe.

## Descargas de Century Gothic y Arial Narrow

Estas dos familias no están en `corefonts` ni `vista-fonts`. El paquete local
`nixos/packages/microsoft-office-fonts.nix` las extrae automáticamente de dos
descargas oficiales de Microsoft, verificadas por SHA-256:

- Century Gothic: instalador de Excel para Mac 15.11.1, con los cuatro estilos.
- Arial Narrow: actualización de Office 2010 KB2589386, con los cuatro estilos.

Se extraen únicamente datos de los archivos; no se ejecutan los instaladores
ni sus scripts. El paquete comprueba con `fc-scan` las dos familias y los ocho
estilos antes de terminar. No se necesita aportar una partición de Windows.

La primera descarga de Excel ocupa unos **703 MiB**; la actualización de Arial
Narrow, unos **370 KiB**. El paquete final conserva los ocho archivos de fuentes
y los metadatos de distribución. Los archivos originales permanecen en el
almacén de Nix mientras sean necesarios para reconstruir el paquete.

La receta local se mantiene como paquete no libre, igual que `vista-fonts`.
Las referencias de origen son la fórmula
[Office Preview de Fontist](https://github.com/fontist/formulas/blob/9c36b5e7e5c81afc37b95a83b7496f8546b79244/Formulas/office_preview.yml),
el [catálogo oficial de KB2589386](https://www.catalog.update.microsoft.com/Search.aspx?q=KB2589386)
y las fichas de [Century Gothic](https://learn.microsoft.com/en-us/typography/font-list/century-gothic)
y [Arial Narrow](https://learn.microsoft.com/en-us/typography/font-list/arial-narrow).
