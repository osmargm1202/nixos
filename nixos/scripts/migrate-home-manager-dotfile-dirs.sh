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
			if [ ! -d "$target" ]; then
				printf 'Refusing to migrate symlink without a readable directory: %s -> %s\n' \
					"$target" "$link_target" >&2
				exit 1
			fi

			# Detach external directories before leaf cleanup. Dereference nested
			# links too, so cleanup can never reach back into their source trees.
			staging="$(mktemp -d "${target}.hm-migration.XXXXXX")"
			if ! cp -aL "$target/." "$staging/"; then
				rm -rf "$staging"
				exit 1
			fi
			# Keep the original relative link in the same parent directory.
			backup="${staging}.original-link"
			mv -T "$target" "$backup"
			mv -T "$staging" "$target"
			printf 'Migrated external directory: %s (original link: %s)\n' \
				"$target" "$backup"
			;;
		esac
	fi

	if [ ! -e "$target" ] && [ ! -L "$target" ]; then
		mkdir -p "$target"
	fi
done
