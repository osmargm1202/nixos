#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME=${CONTAINER_NAME:-arch}
IMAGE=${IMAGE:-archlinux:latest}
DOTFILES_REPO=${DOTFILES_REPO:-$HOME/Hobby/dotfiles}
DOTFILES_REPO_URL=${DOTFILES_REPO_URL:-https://github.com/osmargm1202/dotfiles.git}
SCRIPT_PATH=$(readlink -f "${BASH_SOURCE[0]}")

usage() {
	cat <<'USAGE'
Usage: packages/arch/distrobox.sh COMMAND

Commands:
  create      Create the Arch distrobox container.
  enter       Enter the Arch distrobox container.
  bootstrap   Install paru, Arch packages, pi, orgmrnc, and pnpm inside container.
  all         Create then bootstrap.

Environment:
  CONTAINER_NAME      Container name (default: arch)
  IMAGE               Distrobox image (default: archlinux:latest)
  DOTFILES_REPO       Dotfiles checkout path (default: ~/Hobby/dotfiles)
  DOTFILES_REPO_URL   Git URL used when DOTFILES_REPO does not exist.
USAGE
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

create_container() {
	distrobox-create \
		--name "$CONTAINER_NAME" \
		--image "$IMAGE" \
		--volume /run/user/1000/podman/podman.sock:/var/run/docker.sock:ro \
		--volume /etc/hosts:/etc/hosts:ro \
		--init-hooks 'sudo groupadd -f docker; sudo usermod -aG docker $USER' \
		--additional-flags "--privileged" \
		--nvidia
}

enter_container() {
	distrobox-enter "$CONTAINER_NAME"
}

bootstrap_container() {
	distrobox-enter "$CONTAINER_NAME" -- bash "$SCRIPT_PATH" inside-bootstrap
}

ensure_repo() {
	if [[ -d "$DOTFILES_REPO/.git" ]]; then
		git -C "$DOTFILES_REPO" pull --ff-only || printf 'warning: could not fast-forward %s\n' "$DOTFILES_REPO" >&2
		return 0
	fi

	mkdir -p "$(dirname "$DOTFILES_REPO")"
	git clone "$DOTFILES_REPO_URL" "$DOTFILES_REPO"
}

install_node_tools() {
	run_as_root pacman -S --needed --noconfirm npm pnpm
	if command -v corepack >/dev/null 2>&1; then
		corepack enable || true
	fi
	run_as_root npm install -g @earendil-works/pi-coding-agent orgmrnc
}

inside_bootstrap() {
	run_as_root pacman -Syu --needed --noconfirm git base-devel sudo npm pnpm
	run_as_root groupadd -f docker
	run_as_root usermod -aG docker "$USER"
	ensure_repo
	bash "$DOTFILES_REPO/packages/arch/install.sh"
	install_node_tools
	printf 'Arch distrobox bootstrap complete. Re-enter container so docker group membership refreshes.\n'
}

main() {
	case "${1:-}" in
		create)
			create_container
			;;
		enter)
			enter_container
			;;
		bootstrap)
			bootstrap_container
			;;
		all)
			create_container
			bootstrap_container
			;;
		inside-bootstrap)
			inside_bootstrap
			;;
		-h|--help|help)
			usage
			;;
		*)
			usage >&2
			return 2
			;;
	esac
}

main "$@"
