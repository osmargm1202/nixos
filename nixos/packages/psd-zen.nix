{ pkgs }:
pkgs.profile-sync-daemon.overrideAttrs (old: {
  # profile-sync-daemon's installPhase is a raw custom script that never calls
  # `runHook postInstall`, so a postInstall attr here would silently never run.
  installPhase = old.installPhase + ''
    cat > $out/share/psd/browsers/zen <<'BROWSER_CONF'
    if [[ -d "$HOME"/.zen ]]; then
        index=0
        PSNAME="zen-browser"
        while read -r profileItem; do
            if [[ $(echo "$profileItem" | cut -c1) = "/" ]]; then
                DIRArr[$index]="$profileItem"
            else
                DIRArr[$index]="$HOME/.zen/$profileItem"
            fi
            (( index=index+1 ))
        done < <(grep '[Pp]'ath= "$HOME"/.zen/profiles.ini | sed 's/[Pp]ath=//')
    fi

    check_suffix=1
    BROWSER_CONF
  '';
})
