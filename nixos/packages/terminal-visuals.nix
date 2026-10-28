{ callPackage, symlinkJoin, writeText, writeShellScriptBin, makeDesktopItem, cava, peaclock }:
let
  rmatrix = callPackage ./rmatrix.nix { };
  cavaDefaults = writeText "orgm-cava.ini" ''
    [general]
    framerate = 30
    sleep_timer = 5
    [input]
    method = pulse
    source = auto
    [output]
    method = noncurses
  '';
  cavaLauncher = writeShellScriptBin "cava" ''
    custom=false
    for argument in "$@"; do
      case "$argument" in -p|-p?*) custom=true ;; esac
    done
    if "$custom" || [ -f "''${XDG_CONFIG_HOME:-$HOME/.config}/cava/config" ]; then
      exec ${cava}/bin/cava "$@"
    fi
    exec ${cava}/bin/cava -p ${cavaDefaults} "$@"
  '';
  desktop = name: title: icon: categories: makeDesktopItem {
    name = "orgm-${name}";
    desktopName = title;
    exec = name;
    inherit icon categories;
    terminal = true;
    startupNotify = false;
  };
in symlinkJoin {
  name = "orgm-terminal-visuals";
  paths = [
    rmatrix cavaLauncher peaclock
    (desktop "rmatrix" "RMatrix" "utilities-terminal" [ "Utility" ])
    (desktop "peaclock" "Peaclock" "preferences-system-time" [ "Utility" "Clock" ])
    (desktop "cava" "CAVA" "multimedia-volume-control" [ "AudioVideo" ])
  ];
  passthru = { inherit cavaDefaults; };
  meta.description = "Shared native terminal rain, clock and music visualizer";
}
