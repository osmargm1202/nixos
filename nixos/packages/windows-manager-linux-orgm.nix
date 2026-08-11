{
  lib,
  runCommand,
  python3,
  pkgs,
  zip,
  ...
}:
runCommand "windows-manager-linux-orgm" {
  nativeBuildInputs = [ zip ];
  meta = {
    description = "Native browser bridge that focuses an existing web application tab";
    platforms = lib.platforms.linux;
  };
} ''
  install -Dm755 ${./windows-manager-linux-orgm/native-host.py} "$out/libexec/windows-manager-linux-orgm-host.py"
  install -d "$out/bin"
  cat > "$out/bin/windows-manager-linux-orgm-tab" <<EOF
  #!${pkgs.runtimeShell}
  exec ${python3}/bin/python3 "$out/libexec/windows-manager-linux-orgm-host.py" --client "\$@"
  EOF
  chmod 0755 "$out/bin/windows-manager-linux-orgm-tab"
  cat > "$out/bin/windows-manager-linux-orgm-tabs" <<EOF
  #!${pkgs.runtimeShell}
  exec ${python3}/bin/python3 "$out/libexec/windows-manager-linux-orgm-host.py" --tabs-client "\$@"
  EOF
  chmod 0755 "$out/bin/windows-manager-linux-orgm-tabs"


  cat > "$out/libexec/windows-manager-linux-orgm-host" <<EOF
  #!${pkgs.runtimeShell}
  exec ${python3}/bin/python3 "$out/libexec/windows-manager-linux-orgm-host.py"
  EOF
  chmod 0755 "$out/libexec/windows-manager-linux-orgm-host"

  install -d "$out/lib/mozilla/native-messaging-hosts"
  cat > "$out/lib/mozilla/native-messaging-hosts/windows_manager_linux_orgm.json" <<EOF
  {
    "name": "windows_manager_linux_orgm",
    "description": "ORGM browser tab bridge",
    "path": "$out/libexec/windows-manager-linux-orgm-host",
    "type": "stdio",
    "allowed_extensions": ["windows_manager_linux_orgm@or-gm.com"]
  }
  EOF

  install -d "$out/share/windows-manager-linux-orgm" "$TMPDIR/xpi-inputs"
  cp ${./windows-manager-linux-orgm/manifest.json} "$TMPDIR/xpi-inputs/manifest.json"
  cp ${./windows-manager-linux-orgm/background.js} "$TMPDIR/xpi-inputs/background.js"
  zip -X -j -q "$out/share/windows-manager-linux-orgm/windows-manager-linux-orgm-unsigned.xpi" \
    "$TMPDIR/xpi-inputs/manifest.json" \
    "$TMPDIR/xpi-inputs/background.js"
''
