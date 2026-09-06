#!/usr/bin/env bash
# Post-rebuild dotfiles completeness audit.
# Run after: nh os switch
# Usage: tests/dotfiles-audit.sh [--backup PATH]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG="$HOME/.config"
RECORD="$HOME/.dotfiles-config-backup"
REPORT="$HOME/dotfiles-audit-$(date +%Y%m%d-%H%M%S).md"

# ── Find backup ──────────────────────────────────────────────────────────────
BACKUP=""
if [ "${1:-}" = "--backup" ] && [ -n "${2:-}" ]; then
    BACKUP="$2"
elif [ -f "$RECORD" ]; then
    BACKUP=$(cat "$RECORD")
else
    BACKUP=$(ls -dt "$HOME"/.config.bak-* 2>/dev/null | head -1 || true)
fi

if [ -z "$BACKUP" ] || [ ! -d "$BACKUP" ]; then
    echo "ERROR: No backup found. Run tests/dotfiles-backup.sh first."
    exit 1
fi

# Discover managed top-level .config directories from every dotfile layer.
TRACKED_CONFIG="$(
    find "$DOTFILES_REPO/config" \( -type f -o -type l \) -path '*/.config/*' -printf '%P\n' \
        | sed -E 's#^.*/\.config/([^/]+).*#\1#' \
        | sort -u
)"

# ── AUTO-GENERATED: program writes these — tracking causes conflicts ──────────
AUTO_GEN_EXTRA=(
    hyprpanel caelestia nwg-displays spicetify eww ags
    orgm orgmai orgmcalc orgmenv orgmorg orgmprop orgmrnc
    opencode obsidian warp limux tokscale noctalia dgop elephant
    rofi-hyprchy waybar-hyprchy
    mimeapps.list monitors.xml "monitors.xml~" dconf-backup.txt
    gtkrc gtkrc-2.0 user-share user-dirs.dirs user-dirs.locale
    environment.d fontconfig session xsettingsd enchant
    background autostart superpowers nwg-look
)

# ── SKIP: cache / browser / KDE-Plasma state / dev runtime ──────────────────
SKIP_EXACT=(
    chromium "google-chrome" "google-chrome-for-testing" Code cursor Cursor
    dconf pulse go pnpm gcloud gopls "github-copilot"
    matplotlib models configstore ibus
    GIMP unity3d "gnome-initial-setup-done"
    geary evolution epiphany gsconnect "goa-1.0" yelp
    Rygel rygel.conf "print-manager"
    freerdp connections.db "gtk-3.0"
    "Trolltech.conf" "QtProject.conf" qtengine
    lazygit gh git
    nautilus "nautilus.bak" nemo Thunar "dolphin-emu" LibreCAD
    BetterDiscord Vencord equibop Equicord legcord vesktop "discord-window-shot.conf"
    steamfetch sunshine winapps winboat Nextcloud rclone
    smithery neonctl "com.strapi" "create-next-app-nodejs" "nextjs-nodejs"
    htop nvtop pacseek qalculate pavucontrol.ini
    paperwm walker peaclock yay arkrc menus "nwg-drawer"
    "cosmic" astro
    discoverrc "dleyna-server-service.conf" drkonqirc filetypesrc
    gwenviewrc KDE okularpartrc okularrc systemmonitorrc trashrc
    ".gsd-keyboard.settings-ported" gga
    cava ghostty thefuck zed fuzzel glow television
)

SKIP_PREFIXES=(
    plasma kde kwin baloo kactivity kate konsole
    kscreen ksmserver ksplash kconf kglobal khelp krdp
    kscreenlocker ktime kwallet kxkb kaccess kcminput
    power spectacle baloofile
    okular gwenview discover drkonqi
)


# ── Helpers ───────────────────────────────────────────────────────────────────
in_list() {
    local needle="$1"; shift
    local item
    for item in "$@"; do [ "$item" = "$needle" ] && return 0; done
    return 1
}

starts_with_any() {
    local name="$1"; shift
    for prefix in "$@"; do
        [[ "$name" == "$prefix"* ]] && return 0
    done
    return 1
}

is_tracked() { grep -qxF "$1" <<< "$TRACKED_CONFIG"; }

is_auto_gen() {
    in_list "$1" "${AUTO_GEN_EXTRA[@]}"
}

is_skip() {
    in_list "$1" "${SKIP_EXACT[@]}" && return 0
    starts_with_any "$1" "${SKIP_PREFIXES[@]}" && return 0
    # KDE *rc pattern
    [[ "$1" =~ ^[kK].*rc$ ]] && return 0
    return 1
}


# ── Gather items ─────────────────────────────────────────────────────────────
mapfile -t BACKUP_ITEMS < <(find "$BACKUP" -maxdepth 1 -mindepth 1 -printf '%f\n' | sort -u)
mapfile -t CURRENT_ITEMS < <(find "$CONFIG" -maxdepth 1 -mindepth 1 -printf '%f\n' 2>/dev/null | sort -u || true)

# ── Categorize backup items ──────────────────────────────────────────────────
declare -a C_TRACKED=()
declare -a C_TRACKED_MISSING=()
declare -a C_ADD_DOTFILES=()
declare -a C_AUTO_GEN=()
declare -a C_SKIP=()
declare -a C_NEW=()

for item in "${BACKUP_ITEMS[@]}"; do
    in_current=false
    [ -e "$CONFIG/$item" ] && in_current=true

    if is_tracked "$item"; then
        if $in_current; then
            C_TRACKED+=("$item")
        else
            C_TRACKED_MISSING+=("$item")
        fi
    elif is_auto_gen "$item"; then
        C_AUTO_GEN+=("$item")
    elif is_skip "$item"; then
        C_SKIP+=("$item")
    else
        $in_current || C_ADD_DOTFILES+=("$item")
    fi
done

# New dirs created by NixOS/HM rebuild (in current but not in backup)
for item in "${CURRENT_ITEMS[@]}"; do
    in_list "$item" "${BACKUP_ITEMS[@]}" || C_NEW+=("$item")
done


# ── Write report ─────────────────────────────────────────────────────────────
{
cat <<HDR
# Dotfiles Completeness Audit

- **Date:** $(date)
- **Backup:** \`$BACKUP\`
- **Current:** \`$CONFIG\`

HDR

echo "## ✅ TRACKED — deployed correctly (${#C_TRACKED[@]})"
[ ${#C_TRACKED[@]} -gt 0 ] && printf ' - `%s`\n' "${C_TRACKED[@]}" || echo " *(none)*"
echo ""

echo "## ⚠️ TRACKED BUT MISSING — absent after rebuild (${#C_TRACKED_MISSING[@]})"
[ ${#C_TRACKED_MISSING[@]} -gt 0 ] && printf ' - `%s`\n' "${C_TRACKED_MISSING[@]}" || echo " *(none — all deployed)*"
echo ""

echo "## ➕ ADD TO DOTFILES — had config before, gone after rebuild (${#C_ADD_DOTFILES[@]})"
[ ${#C_ADD_DOTFILES[@]} -gt 0 ] && printf ' - `%s`\n' "${C_ADD_DOTFILES[@]}" || echo " *(none — full coverage!)*"
echo ""

echo "## 🔄 AUTO-GENERATED — program writes these, do not track (${#C_AUTO_GEN[@]})"
[ ${#C_AUTO_GEN[@]} -gt 0 ] && printf ' - `%s`\n' "${C_AUTO_GEN[@]}" || echo " *(none)*"
echo ""

echo "## ⏭️ SKIP — cache/browser/KDE state (${#C_SKIP[@]})"
[ ${#C_SKIP[@]} -gt 0 ] && printf ' - `%s`\n' "${C_SKIP[@]}" || echo " *(none)*"
echo ""

echo "## 🆕 NEW FROM REBUILD — created by NixOS/HM, not in backup (${#C_NEW[@]})"
[ ${#C_NEW[@]} -gt 0 ] && printf ' - `%s`\n' "${C_NEW[@]}" || echo " *(none)*"
echo ""

echo ""

echo "---"
printf "Backup: %d | Tracked: %d | Missing: %d | Add dotfiles: %d | Auto-gen: %d | Skip: %d\n" \
    "${#BACKUP_ITEMS[@]}" "${#C_TRACKED[@]}" "${#C_TRACKED_MISSING[@]}" \
    "${#C_ADD_DOTFILES[@]}" "${#C_AUTO_GEN[@]}" "${#C_SKIP[@]}"

} | tee "$REPORT"

echo ""
echo "Report: $REPORT"
