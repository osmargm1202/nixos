{
  lib,
  runCommand,
  librsvg,
  plymouth,
  logo,
}:
runCommand "plymouth-thinkpad-bgrt" {
  nativeBuildInputs = [ librsvg ];
  passthru.themeName = "thinkpad-bgrt";
  meta.description = "Stock BGRT spinner with a ThinkPad fallback and NixOS watermark";
} ''
  theme="$out/share/plymouth/themes/thinkpad-bgrt"
  mkdir -p "$theme"
  cp ${plymouth}/share/plymouth/themes/spinner/*.png "$theme/"
  cp ${plymouth}/share/plymouth/themes/bgrt/bgrt.plymouth "$theme/thinkpad-bgrt.plymouth"
  sed -i "s|^ImageDir=.*|ImageDir=$theme|" "$theme/thinkpad-bgrt.plymouth"

  # Keep the original outline and red TrackPoint; white lettering on black.
  printf 'path { fill: #ffffff; }\n' > white.css
  rsvg-convert --stylesheet white.css --width 320 \
    ${../assets/thinkpad/thinkpad.svg} --output "$theme/bgrt-fallback.png"
  cp ${lib.escapeShellArg logo} "$theme/watermark.png"
''
