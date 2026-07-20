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

    if ! "$flatpak_bin" info ${appId} >/dev/null 2>&1; then
      printf 'Discord Flatpak %s is not installed\n' ${appId} >&2
      exit 1
    fi

    has_policy=false
    for arg in "$@"; do
      case "$arg" in
        --force-webrtc-ip-handling-policy=*) has_policy=true ;;
      esac
    done

    if [[ "$has_policy" == true ]]; then
      exec "$flatpak_bin" run ${appId} "$@"
    fi
    exec "$flatpak_bin" run ${appId} ${policy} "$@"
  '';
  meta.mainProgram = "discord";
}
