{ fetchFromGitHub, tmuxPlugins }:
tmuxPlugins.mkTmuxPlugin {
  pluginName = "tmux-pane-tree";
  version = "unstable-2026-07-06";
  src = fetchFromGitHub {
    owner = "sandudorogan";
    repo = "tmux-pane-tree";
    rev = "6e52b03d1f57ec38bb17bb3ce06f98a7afa18fd5";
    hash = "sha256-uMDGpT/a6iFDYF6IS7dR+pNUSXQAmTn41w5Ms6xTiZU=";
  };
}
