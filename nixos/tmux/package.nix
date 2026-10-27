{ pkgs }:
let
  agents = pkgs.writeScriptBin "tmux-agent-resume" ''
    #!${pkgs.python3}/bin/python3
    RESOURCE_DIR = "${./hooks}"
    ${builtins.readFile ./agents.py}
  '';
  saveProxy = pkgs.writeShellScript "orgm-tmux-save" ''
    exec tmux-session save
  '';
  session = pkgs.writeShellApplication {
    name = "tmux-session";
    runtimeInputs = [ pkgs.tmux pkgs.coreutils pkgs.util-linux pkgs.procps agents ];
    text = ''
      RESURRECT=${pkgs.tmuxPlugins.resurrect}/share/tmux-plugins/resurrect
      CONTINUUM=${pkgs.tmuxPlugins.continuum}/share/tmux-plugins/continuum
      SAVE_PROXY=${saveProxy}
      ${builtins.readFile ./session.sh}
    '';
  };
in pkgs.symlinkJoin {
  name = "orgm-tmux-session";
  paths = [ agents session ];
}
