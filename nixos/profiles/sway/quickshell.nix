{ pkgs }:
# Quickshell's upstream wrapper includes SVG but not Qt's WebP decoder.
# Wrap the binary rather than setting a session-wide, possibly mixed-Qt path.
pkgs.symlinkJoin {
  name = "quickshell-${pkgs.quickshell.version}";
  inherit (pkgs.quickshell) pname version;
  paths = [ pkgs.quickshell ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    for binary in qs quickshell; do
      wrapProgram "$out/bin/$binary" \
        --prefix QT_PLUGIN_PATH : "${pkgs.qt6.qtimageformats}/lib/qt-6/plugins"
    done
  '';
}
