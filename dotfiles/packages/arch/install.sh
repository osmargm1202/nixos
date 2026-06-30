#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PACKAGES_FILE="$SCRIPT_DIR/packages.lst"
AUR_PACKAGES_FILE="$SCRIPT_DIR/aur-packages.lst"

trim() {
	local value=$1
	value=${value#"${value%%[![:space:]]*}"}
	value=${value%"${value##*[![:space:]]}"}
	printf '%s\n' "$value"
}

run_as_root() {
	if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
		"$@"
	elif command -v sudo >/dev/null 2>&1; then
		sudo "$@"
	else
		printf 'sudo required for: %s\n' "$*" >&2
		return 1
	fi
}

install_with_pacman() {
	run_as_root pacman -S --needed "$@"
}

ensure_paru() {
	if command -v paru >/dev/null 2>&1; then
		return 0
	fi

	if ! command -v git >/dev/null 2>&1; then
		install_with_pacman git
	fi

	if ! command -v makepkg >/dev/null 2>&1; then
		install_with_pacman base-devel
	elif ! pacman -Qq base-devel >/dev/null 2>&1; then
		install_with_pacman base-devel
	fi

	local build_dir
	local status=0
	build_dir=$(mktemp -d)

	git clone https://aur.archlinux.org/paru.git "$build_dir/paru" || {
		status=$?
		printf 'git clone failed with status %s\n' "$status" >&2
	}

	if [[ $status -eq 0 ]]; then
		(
			cd "$build_dir/paru"
			makepkg -si --noconfirm
		) || {
			status=$?
			printf 'makepkg failed with status %s\n' "$status" >&2
		}
	fi

	rm -rf "$build_dir"
	return "$status"
}

load_packages() {
	local file=$1
	local line

	[[ -f "$file" ]] || return 0

	while IFS= read -r line || [[ -n "$line" ]]; do
		line=$(trim "$line")
		[[ -z "$line" || "$line" == \#* ]] && continue
		printf '%s\n' "$line"
	done <"$file"
}

main() {
	local -a packages=()

	mapfile -t packages < <(
		{
			load_packages "$PACKAGES_FILE"
			load_packages "$AUR_PACKAGES_FILE"
		} | LC_ALL=C sort -u
	)

	if [[ ${#packages[@]} -eq 0 ]]; then
		printf 'No packages listed. Nothing to install.\n'
		return 0
	fi

	ensure_paru
	paru -S --needed "${packages[@]}"
}

main "$@"
