{ pkgs }:
pkgs.writeShellScriptBin "orgm-osk-engine" ''
  export ORGM_OSK_XKBCOMMON="${pkgs.libxkbcommon}/lib/libxkbcommon.so.0"
  export ORGM_OSK_XDOTOOL="${pkgs.xdotool}/bin/xdotool"
  exec ${pkgs.python3}/bin/python3 ${./engine.py}
''
