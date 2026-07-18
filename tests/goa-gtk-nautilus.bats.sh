#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

assert_goa_after_nautilus() {
	local file="$1"
	awk '
    $1 == "nautilus" {
      getline
      if ($1 == "gnome-online-accounts-gtk") found = 1
    }
    END { exit found ? 0 : 1 }
  ' "$file" || fail "gnome-online-accounts-gtk must follow nautilus in $file"
}

for profile in \
	nixos/profiles/common_hyprland.nix \
	nixos/profiles/gnome.nix \
	nixos/profiles/i3.nix \
	nixos/profiles/labwc.nix; do
	assert_goa_after_nautilus "$ROOT/$profile"
done

if grep -Eq '^[[:space:]]+gnome-online-accounts-gtk([[:space:]]|$)' "$ROOT/nixos/common.nix"; then
	fail "gnome-online-accounts-gtk must not be global"
fi

for profile in \
	nixos/profiles/common_hyprland.nix \
	nixos/profiles/i3.nix \
	nixos/profiles/labwc.nix; do
	grep -Fq 'services.gnome.gnome-online-accounts.enable = true;' "$ROOT/$profile" ||
		fail "GOA backend must be enabled in $profile"
done

printf 'PASS: GOA GTK frontend and backend configured together\n'
