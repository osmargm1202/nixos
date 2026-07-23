#!/usr/bin/env bash
set -euo pipefail

for relative_path in "$@"; do
	target="$HOME/$relative_path"

	if [ -L "$target" ]; then
		link_target="$(readlink "$target")"
		case "$link_target" in
		/nix/store/*-home-manager-files/"$relative_path")
			rm "$target"
			;;
		*)
			printf 'Refusing to remove unexpected symlink: %s -> %s\n' \
				"$target" "$link_target" >&2
			exit 1
			;;
		esac
	fi

	if [ ! -e "$target" ] && [ ! -L "$target" ]; then
		mkdir -p "$target"
	fi
done
