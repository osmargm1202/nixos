{ pkgs }:
let
  python = pkgs.python3.withPackages (ps: [ ps.xlib ]);
in
pkgs.writeShellScriptBin "orgm-x11-client-pid" ''
  exec ${python}/bin/python3 -B ${./x11-client-pid.py} "$@"
''
