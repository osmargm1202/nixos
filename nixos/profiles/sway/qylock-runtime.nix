{ lib, stdenvNoCC, callPackage, python3, ffmpeg, makeWrapper, quickshell,
  qt6, kdePackages, pam, fprintd, systemd, defaultTheme ? "winter" }:
let
  source = (callPackage ../../sddm/sddm-qylock.nix { theme = "forest"; }).src;
  qmlPath = lib.makeSearchPath "lib/qt-6/qml" [ qt6.qtdeclarative qt6.qt5compat qt6.qtmultimedia qt6.qtsvg ];
  pluginPath = lib.makeSearchPath "lib/qt-6/plugins" [ qt6.qtbase qt6.qtwayland qt6.qt5compat qt6.qtmultimedia qt6.qtsvg ];
  greeterEnvironment = {
    QML_XHR_ALLOW_FILE_READ = "1";
    QML_IMPORT_PATH = "${qmlPath}:${kdePackages.sddm}/share/sddm/components";
    QML2_IMPORT_PATH = "${qmlPath}:${kdePackages.sddm}/share/sddm/components";
    QT_PLUGIN_PATH = pluginPath;
    QT_MEDIA_BACKEND = "ffmpeg";
  };
in
stdenvNoCC.mkDerivation {
  pname = "orgm-qylock";
  version = "1.0";
  dontUnpack = true;
  nativeBuildInputs = [ python3 ffmpeg makeWrapper ];
  installPhase = ''
    runHook preInstall
    base="$out/share/orgm-qylock"
    mkdir -p "$base/imports" "$base/pam" "$out/bin"
    ln -s ${source}/themes "$base/themes"
    ln -s ${source} "$base/upstream"
    cp ${source}/LICENSE "$base/LICENSE"
    cp -r ${source}/quickshell-lockscreen/imports/SddmComponents "$base/imports/"
    cp -r ${../../../dotfiles/config/profiles/sway/.config/quickshell/orgm-lock} "$base/qml"
    cp -r ${../../../dotfiles/config/profiles/sway/.config/quickshell/orgm-locks} "$base/picker"
    ${python3}/bin/python3 ${./qylock-catalog.py} ${source} "$base"
    cat > "$base/pam/orgm-qylock-pw" <<EOF
    #%PAM-1.0
    auth required ${pam}/lib/security/pam_unix.so
    account required ${pam}/lib/security/pam_unix.so
    EOF
    cat > "$base/pam/orgm-qylock-fp" <<EOF
    #%PAM-1.0
    auth required ${fprintd}/lib/security/pam_fprintd.so timeout=30 max_tries=3
    account required ${pam}/lib/security/pam_unix.so
    EOF
    cp ${./qylock-apply.py} "$out/bin/orgm-qylock-apply"
    substituteInPlace "$out/bin/orgm-qylock-apply" \
      --replace-fail '@package@' "$out" \
      --replace-fail '@default_theme@' '${defaultTheme}' \
      --replace-fail '@qt_environment@' '${builtins.toJSON greeterEnvironment}'
    chmod 755 "$out/bin/orgm-qylock-apply"
    patchShebangs "$out/bin/orgm-qylock-apply"
    makeWrapper ${quickshell}/bin/qs "$out/bin/orgm-qylock-qs" \
      --prefix QML2_IMPORT_PATH : "$base/imports:${qmlPath}" \
      --prefix QML_IMPORT_PATH : "$base/imports:${qmlPath}" \
      --prefix QT_PLUGIN_PATH : '${pluginPath}' \
      --prefix PATH : '${lib.makeBinPath [ systemd ]}' \
      --set QML_XHR_ALLOW_FILE_READ 1 --set QT_MEDIA_BACKEND ffmpeg
    OUT="$out" ${python3}/bin/python3 - <<'PY'
    import json, os
    from pathlib import Path
    out = Path(os.environ['OUT'])
    base = out/'share/orgm-qylock'
    data = dict(schema=1, catalog=str(base/'catalog.json'), themes=str(base/'themes'),
        previews=str(base/'previews'), qs=str(out/'bin/orgm-qylock-qs'),
        apply=str(out/'bin/orgm-qylock-apply'), pamDirectory=str(base/'pam'),
        lockQml=str(base/'qml/lock.qml'), pickerQml=str(base/'picker'),
        defaultTheme='${defaultTheme}', fingerprintList='${fprintd}/bin/fprintd-list',
        greeterEnvironment=json.loads('${builtins.toJSON greeterEnvironment}'))
    (base/'runtime.json').write_text(json.dumps(data, indent=2)+'\n')
    PY
    runHook postInstall
  '';
  passthru = { inherit source greeterEnvironment; };
  meta = {
    description = "Complete pinned qylock catalog and Quickshell session-lock runtime";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
  };
}
