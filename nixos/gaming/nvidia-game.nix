{ pkgs }:
pkgs.writeShellApplication {
  name = "nvidia-game";
  text = ''
    if ! command -v nvidia-offload >/dev/null 2>&1; then
      printf '%s\n' 'NVIDIA PRIME offload is unavailable; refusing to fall back to Intel.' >&2
      exit 1
    fi
    exec nvidia-offload "$@"
  '';
}
