#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Exercise common-dotfiles itself, not a duplicate of its source filter. The
# cached locked lib is used offline; neither evaluation nor filtering runs Git.
nixpkgs="$(nix eval --offline --impure --raw --expr "(builtins.getFlake \"path:$ROOT\").inputs.nixpkgs.outPath")"
for tree in clean noisy; do
  mkdir -p "$tmp/$tree/nixos" "$tmp/$tree/lib" "$tmp/$tree/dotfiles/config/programs/demo/.config/demo" \
    "$tmp/$tree/dotfiles/config/programs/demo/.local/bin" \
    "$tmp/$tree/dotfiles/config/profiles/fixture" \
    "$tmp/$tree/dotfiles/config/users/test/common" \
    "$tmp/$tree/dotfiles/config/hosts/test/shared"
  cp "$ROOT/nixos/common-dotfiles.nix" "$tmp/$tree/nixos/"
  cp "$ROOT"/lib/*.nix "$tmp/$tree/lib/"
  printf 'real application settings\n' > "$tmp/$tree/dotfiles/config/programs/demo/.config/demo/settings"
  printf '#!/usr/bin/env bash\nprintf "fixture executable\\n"\n' > "$tmp/$tree/dotfiles/config/programs/demo/.local/bin/demo"
  chmod +x "$tmp/$tree/dotfiles/config/programs/demo/.local/bin/demo"
  ln -s demo "$tmp/$tree/dotfiles/config/programs/demo/.local/bin/demo-link"
  printf profile > "$tmp/$tree/dotfiles/config/profiles/fixture/.profile-fixture"
  printf user > "$tmp/$tree/dotfiles/config/users/test/common/.user-fixture"
  printf host > "$tmp/$tree/dotfiles/config/hosts/test/shared/.host-fixture"
done
noisy="$tmp/noisy/dotfiles/config"
mkdir -p "$noisy/shared/.config/obsolete" "$noisy/unused/empty" \
  "$noisy/programs/demo/.config/demo/__pycache__" "$noisy/programs/demo/.git" \
  "$noisy/profiles/fixture/empty/nested"
printf ignored > "$noisy/shared/.config/obsolete/settings"
printf bytecode > "$noisy/programs/demo/.config/demo/__pycache__/settings.pyc"
for metadata in .gitignore .DS_Store icon-theme.cache mimeinfo.cache settings.bak settings~ $'Icon\r'; do
  printf metadata > "$noisy/programs/demo/.config/demo/$metadata"
done
printf git > "$noisy/programs/demo/.git/index"
cp -a "$tmp/clean" "$tmp/changed"
printf 'changed application settings\n' > "$tmp/changed/dotfiles/config/programs/demo/.config/demo/settings"

for tree in clean noisy changed; do
  nix eval --offline --impure --json --expr "
    let
      lib = import $nixpkgs/lib;
      module = import $tmp/$tree/nixos/common-dotfiles.nix {
        inherit lib;
        pkgs = {};
        config = { networking.hostName = \"test\"; orgm.user.programs = [ \"demo\" ]; };
        userName = \"test\";
        profileName = \"fixture\";
      };
      home = module.home-manager.users.test { inherit lib; config = {}; pkgs = {}; };
    in builtins.mapAttrs (_: file: toString file.source) home.home.file
  " > "$tmp/$tree.json"
done

python3 - "$tmp" <<'PY'
import json
import os
from pathlib import Path
import subprocess
import sys

root = Path(sys.argv[1])
clean = json.loads((root / "clean.json").read_text())
noisy = json.loads((root / "noisy.json").read_text())
expected = {
    ".config/demo/settings": "real application settings\n",
    ".local/bin/demo": '#!/usr/bin/env bash\nprintf "fixture executable\\n"\n',
    ".local/bin/demo-link": '#!/usr/bin/env bash\nprintf "fixture executable\\n"\n',
    ".profile-fixture": "profile",
    ".user-fixture": "user",
    ".host-fixture": "host",
}
for name, files in (("clean", clean), ("noisy", noisy)):
    assert set(files) == set(expected), (name, "selected files changed", files)
    for target, content in expected.items():
        assert Path(files[target]).read_text() == content, (name, target, "content changed")
    script = Path(files[".local/bin/demo"])
    link = Path(files[".local/bin/demo-link"])
    assert os.access(script, os.X_OK), (name, "executable bit lost")
    assert link.is_symlink() and os.readlink(link) == "demo", (name, "relative symlink changed")
    assert subprocess.check_output([str(link)], text=True) == "fixture executable\n"
assert clean == noisy, ("metadata, obsolete roots or empty directories changed immutable source paths", clean, noisy)
changed = json.loads((root / "changed.json").read_text())
assert clean != changed, "a real selected configuration change did not change its source hash"
assert Path(changed[".config/demo/settings"]).read_text() == "changed application settings\n"
print("PASS: selected layers, executables and symlinks survive; ignored metadata/obsolete roots/empty directories do not change source hashes")
PY
