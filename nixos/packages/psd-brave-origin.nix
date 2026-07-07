# Layers a brave-origin browser-conf on top of psd-zen's derivation.
# Config dir isn't flat like ~/.zen — it's ~/.config/BraveSoftware/Brave-Origin-Beta,
# so this mirrors upstream psd's google-chrome conf (single dir, no per-profile loop).
{ psdZen }:
psdZen.overrideAttrs (old: {
  installPhase = old.installPhase + ''
    cat > $out/share/psd/browsers/brave-origin <<'BROWSER_CONF'
    if [[ -n "$CHROME_CONFIG_HOME" ]]; then
        DIRArr[0]="$CHROME_CONFIG_HOME/BraveSoftware/Brave-Origin-Beta"
    else
        DIRArr[0]="$XDG_CONFIG_HOME/BraveSoftware/Brave-Origin-Beta"
    fi
    PSNAME="brave-origin"
    check_suffix=1
    BROWSER_CONF
  '';
})
