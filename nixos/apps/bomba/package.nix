{ pkgs }:
pkgs.writeShellScriptBin "bomba" ''
  export PATH=${pkgs.lib.makeBinPath [ pkgs.openssh ]}:$PATH
  exec ${pkgs.python3}/bin/python3 ${./bomba.py} "$@"
''
