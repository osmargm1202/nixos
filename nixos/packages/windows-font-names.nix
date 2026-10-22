{ lib, runCommand, corefonts, vista-fonts, microsoftOfficeFonts }:

# CAD drawings name TrueType fonts by their Windows file (arial.ttf, arialbd.ttf).
# CADCraft resolves styles by that file name, case-insensitively, and does not use
# fontconfig, so the families must also exist under their Windows names.
let
  corefontsNames = {
    "Andale_Mono.ttf" = "andalemo.ttf";
    "Arial.ttf" = "arial.ttf";
    "Arial_Bold.ttf" = "arialbd.ttf";
    "Arial_Italic.ttf" = "ariali.ttf";
    "Arial_Bold_Italic.ttf" = "arialbi.ttf";
    "Arial_Black.ttf" = "ariblk.ttf";
    "Comic_Sans_MS.ttf" = "comic.ttf";
    "Comic_Sans_MS_Bold.ttf" = "comicbd.ttf";
    "Courier_New.ttf" = "cour.ttf";
    "Courier_New_Bold.ttf" = "courbd.ttf";
    "Courier_New_Italic.ttf" = "couri.ttf";
    "Courier_New_Bold_Italic.ttf" = "courbi.ttf";
    "Georgia.ttf" = "georgia.ttf";
    "Georgia_Bold.ttf" = "georgiab.ttf";
    "Georgia_Italic.ttf" = "georgiai.ttf";
    "Georgia_Bold_Italic.ttf" = "georgiaz.ttf";
    "Impact.ttf" = "impact.ttf";
    "Tahoma.ttf" = "tahoma.ttf";
    "Times_New_Roman.ttf" = "times.ttf";
    "Times_New_Roman_Bold.ttf" = "timesbd.ttf";
    "Times_New_Roman_Italic.ttf" = "timesi.ttf";
    "Times_New_Roman_Bold_Italic.ttf" = "timesbi.ttf";
    "Trebuchet_MS.ttf" = "trebuc.ttf";
    "Trebuchet_MS_Bold.ttf" = "trebucbd.ttf";
    "Trebuchet_MS_Italic.ttf" = "trebucit.ttf";
    "Verdana.ttf" = "verdana.ttf";
    "Verdana_Bold.ttf" = "verdanab.ttf";
    "Verdana_Italic.ttf" = "verdanai.ttf";
    "Verdana_Bold_Italic.ttf" = "verdanaz.ttf";
    "Webdings.ttf" = "webdings.ttf";
  };
  officeNames = {
    "ARIALN.TTF" = "arialn.ttf";
    "ARIALNB.TTF" = "arialnb.ttf";
    "ARIALNI.TTF" = "arialni.ttf";
    "ARIALNBI.TTF" = "arialnbi.ttf";
    "Century Gothic.ttf" = "gothic.ttf";
    "Century Gothic Bold.ttf" = "gothicb.ttf";
    "Century Gothic Italic.ttf" = "gothici.ttf";
    "Century Gothic Bold Italic.ttf" = "gothicbi.ttf";
  };
  links = src: names: lib.concatStrings (lib.mapAttrsToList (from: to: ''
    ln -s ${lib.escapeShellArg "${src}/share/fonts/truetype/${from}"} "$dir/${to}"
    test -e "$dir/${to}"
  '') names);
in
runCommand "windows-font-names" { } ''
  dir="$out/share/fonts/windows-names"
  mkdir -p "$dir"
  ${links corefonts corefontsNames}
  ${links microsoftOfficeFonts officeNames}
  # vista-fonts already ships Windows file names (calibri.ttf, consola.ttf...).
  for font in ${vista-fonts}/share/fonts/truetype/*; do
    ln -s "$font" "$dir/$(basename "$font")"
  done
''
