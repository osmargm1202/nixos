{
  lib,
  writeShellApplication,
  flatpak,
}:

let
  appId = "com.discordapp.Discord";
  policy = "--force-webrtc-ip-handling-policy=default_public_and_private_interfaces";
in
writeShellApplication {
  name = "discord";
  text = ''
    flatpak_bin="''${FLATPAK_BIN:-${lib.getExe flatpak}}"
    args=()

    if ! "$flatpak_bin" info ${appId} >/dev/null 2>&1; then
      printf 'Discord Flatpak %s is not installed\n' ${appId} >&2
      exit 1
    fi

    has_required=false
    for arg in "$@"; do
      case "$arg" in
        --force-webrtc-ip-handling-policy=*)
          if [[ "$arg" == "${policy}" && "$has_required" == false ]]; then
            args+=("$arg")
            has_required=true
          fi
          ;;
        *)
          args+=("$arg")
          ;;
      esac
    done

    if [[ "$has_required" == false ]]; then
      args+=("${policy}")
    fi

    exec "$flatpak_bin" run ${appId} "''${args[@]}"
  '';
  meta.mainProgram = "discord";
}
