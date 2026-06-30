import { execFile } from "node:child_process";
import { promisify } from "node:util";
import type { ExtensionAPI, ExtensionContext, SessionStartEvent } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";

const execFileAsync = promisify(execFile);
const CUSTOM_TYPE = "awareness";

const AWARENESS_SCRIPT = String.raw`
printf '\n===== CONTEXTO GENERAL =====\n'; \
echo "Fecha: $(date)"; \
echo "Usuario: $(whoami)"; \
echo "Host: $(hostname)"; \
echo "PWD: $(pwd)"; \
echo "Shell actual: $SHELL"; \
echo "Terminal: \${TERM:-N/A}"; \
echo "Tmux: \${TMUX:+SI}\${TMUX:-NO}"; \
echo "Distro: $(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || uname -a)"; \
echo "Kernel: $(uname -srmo)"; \
printf '\n===== PROYECTO =====\n'; \
echo "Nombre carpeta: $(basename "$PWD")"; \
echo "Ruta proyecto: $(pwd)"; \
[ -f package.json ] && echo "Node project: $(node -p "require('./package.json').name || 'sin nombre'" 2>/dev/null)"; \
[ -f pyproject.toml ] && echo "Python project: pyproject.toml detectado"; \
[ -f go.mod ] && echo "Go module: $(head -n1 go.mod)"; \
[ -f Cargo.toml ] && echo "Rust project: Cargo.toml detectado"; \
printf '\n===== GIT =====\n'; \
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then \
  echo "Repo root: $(git rev-parse --show-toplevel)"; \
  echo "Branch: $(git branch --show-current)"; \
  echo "Commit: $(git rev-parse --short HEAD)"; \
  echo "Estado:"; git status --short; \
  echo "Remotes:"; git remote -v; \
else \
  echo "No es un repositorio Git"; \
fi; \
printf '\n===== SHELLS Y HERRAMIENTAS =====\n'; \
for c in bash fish zsh git docker podman distrobox tmux nvim vim code python python3 node npm pnpm bun go rustc cargo; do \
  command -v "$c" >/dev/null 2>&1 && echo "$c: $(command -v "$c")"; \
done; \
printf '\n===== VERSIONES =====\n'; \
bash --version 2>/dev/null | head -n1; \
fish --version 2>/dev/null; \
zsh --version 2>/dev/null; \
git --version 2>/dev/null; \
docker --version 2>/dev/null; \
podman --version 2>/dev/null; \
distrobox --version 2>/dev/null; \
tmux -V 2>/dev/null; \
python3 --version 2>/dev/null; \
node --version 2>/dev/null; \
go version 2>/dev/null; \
printf '\n===== CONTENEDORES =====\n'; \
echo "--- Docker ---"; docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || echo "Docker no disponible"; \
echo "--- Podman ---"; podman ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || echo "Podman no disponible"; \
echo "--- Distrobox ---"; distrobox list 2>/dev/null || echo "Distrobox no disponible"; \
command -v distrobox-host-exec >/dev/null 2>&1 && echo "distrobox-host-exec: $(command -v distrobox-host-exec)" || echo "distrobox-host-exec: no disponible"; \
printf '\n===== TMUX =====\n'; \
tmux list-sessions 2>/dev/null || echo "No hay sesiones tmux o tmux no disponible"; \
printf '\n===== ARCHIVOS CLAVE =====\n'; \
find . -maxdepth 2 -type f \( \
-name 'package.json' -o \
-name 'pyproject.toml' -o \
-name 'requirements.txt' -o \
-name 'go.mod' -o \
-name 'Cargo.toml' -o \
-name 'Dockerfile' -o \
-name 'docker-compose.yml' -o \
-name 'compose.yml' -o \
-name '.env' -o \
-name '.env.example' -o \
-name 'flake.nix' \
\) 2>/dev/null | sort; \
printf '\n===== VARIABLES RELEVANTES =====\n'; \
env | grep -E '^(SHELL|TERM|USER|HOME|PWD|PATH|XDG_|WAYLAND_DISPLAY|DISPLAY|SSH_|GIT_|DOCKER_|PODMAN_|CONTAINER|DISTROBOX|TMUX)' | sort; \
printf '\n===== SISTEMA OPERATIVO =====\n'; \
echo "OS: $(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || uname -s)"; \
echo "ID: $(. /etc/os-release 2>/dev/null && echo "$ID" || echo "N/A")"; \
echo "Version ID: $(. /etc/os-release 2>/dev/null && echo "\${VERSION_ID:-N/A}" || echo "N/A")"; \
echo "Kernel: $(uname -srmo)"; \
echo "Arquitectura: $(uname -m)"; \
echo "Init: $(ps -p 1 -o comm= 2>/dev/null || echo "N/A")"; \
echo "Hostname: $(hostname)"; \
echo "Contenedor: $(systemd-detect-virt --container 2>/dev/null || echo "no detectado")"; \
echo "Virtualización: $(systemd-detect-virt 2>/dev/null || echo "no detectado")"; \
echo "WSL: $(grep -qi microsoft /proc/version 2>/dev/null && echo "SI" || echo "NO")"; \
echo "Sesión: \${XDG_SESSION_TYPE:-N/A}"; \
echo "Desktop: \${XDG_CURRENT_DESKTOP:-N/A}"; \
echo "Wayland: \${WAYLAND_DISPLAY:-NO}"; \
echo "Display X11: \${DISPLAY:-NO}"; \
printf '\n===== BINARIOS DISPONIBLES =====\n'; \
printf 'Directorios bin comunes detectados:\n'; \
for d in \
  "$HOME/.local/bin" \
  "$HOME/bin" \
  "$HOME/go/bin" \
  "$HOME/.cargo/bin" \
  "$HOME/.npm-global/bin" \
  "$HOME/.bun/bin" \
  "$HOME/.deno/bin" \
  "$HOME/.pub-cache/bin" \
  "$HOME/.config/composer/vendor/bin" \
  "$HOME/.local/share/gem/ruby"*/bin \
  "/usr/local/bin" \
  "/usr/bin" \
  "/bin" \
  "/run/current-system/sw/bin" \
  "/etc/profiles/per-user/$USER/bin" \
  "/nix/var/nix/profiles/default/bin"; do \
  [ -d "$d" ] && echo "  - $d"; \
done; \
printf '\nBinarios encontrados en directorios personales:\n'; \
for d in \
  "$HOME/.local/bin" \
  "$HOME/bin" \
  "$HOME/go/bin" \
  "$HOME/.cargo/bin" \
  "$HOME/.npm-global/bin" \
  "$HOME/.bun/bin" \
  "$HOME/.deno/bin" \
  "$HOME/.pub-cache/bin" \
  "$HOME/.config/composer/vendor/bin" \
  "$HOME/.local/share/gem/ruby"*/bin; do \
  if [ -d "$d" ]; then \
    echo "--- $d ---"; \
    find "$d" -maxdepth 1 -type f -executable -printf '%f\n' 2>/dev/null | sort | sed 's/^/  /'; \
  fi; \
done
`.replaceAll("\\${", "${");

async function runAwarenessShell(cwd: string): Promise<string> {
	try {
		const { stdout, stderr } = await execFileAsync("bash", ["-lc", AWARENESS_SCRIPT], {
			cwd,
			timeout: 30000,
			maxBuffer: 4 * 1024 * 1024,
		});
		const output = stdout.trim();
		const errorOutput = stderr.trim();
		return [output, errorOutput ? `[stderr]\n${errorOutput}` : ""].filter(Boolean).join("\n");
	} catch (error) {
		const err = error as { stdout?: string | Buffer; stderr?: string | Buffer; message?: string };
		return [
			"[awareness command failed]",
			err.message ?? "unknown error",
			err.stdout ? String(err.stdout).trim() : "",
			err.stderr ? `[stderr]\n${String(err.stderr).trim()}` : "",
		]
			.filter(Boolean)
			.join("\n");
	}
}

async function runGit(args: string[], cwd: string): Promise<string> {
	try {
		const { stdout } = await execFileAsync("git", args, { cwd, timeout: 2000 });
		return stdout.trim();
	} catch {
		return "";
	}
}

export async function buildAwarenessText(ctx: Pick<ExtensionContext, "cwd">): Promise<string> {
	const output = await runAwarenessShell(ctx.cwd);
	if (output) return output;

	const [gitRoot, branch] = await Promise.all([
		runGit(["rev-parse", "--show-toplevel"], ctx.cwd),
		runGit(["branch", "--show-current"], ctx.cwd),
	]);
	return [
		`pwd: ${ctx.cwd}`,
		`git: ${gitRoot || "no git"}`,
		`branch: ${branch || ""}`,
		`tmux: ${process.env.TMUX ? "yes" : "no"}`,
		`nix-shell: ${process.env.IN_NIX_SHELL ? "yes" : "no"}`,
		`container markers: ${process.env.container || "none"}`,
		`os: ${process.platform}`,
	].join("\n");
}

function alreadyInjected(ctx: ExtensionContext): boolean {
	return ctx.sessionManager.getEntries().some((entry) => "customType" in entry && entry.customType === CUSTOM_TYPE);
}

function hasConversationEntries(ctx: ExtensionContext): boolean {
	return ctx.sessionManager.getEntries().some((entry) => {
		if (entry.type !== "message") return false;
		return ["user", "assistant", "toolResult"].includes(entry.message.role);
	});
}

function shouldInjectAwareness(reason: SessionStartEvent["reason"], ctx: ExtensionContext): boolean {
	if (alreadyInjected(ctx)) return false;
	if (reason === "new") return true;
	if (reason === "startup") return !hasConversationEntries(ctx);
	return false;
}

export default function (pi: ExtensionAPI) {
	pi.registerMessageRenderer(CUSTOM_TYPE, (message, _options, theme) => {
		return new Text(theme.fg("muted", "awareness\n") + String(message.content ?? ""), 0, 0);
	});

	pi.on("session_start", async (event, ctx) => {
		if (!shouldInjectAwareness(event.reason, ctx)) return;

		const content = await buildAwarenessText(ctx);
		pi.sendMessage(
			{
				customType: CUSTOM_TYPE,
				content,
				display: true,
				details: { source: "startup-awareness" },
			},
			{ deliverAs: "nextTurn" },
		);
	});
}
