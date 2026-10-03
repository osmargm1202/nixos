config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
colors="${RYOKU_ROFI_COLORS:-${XDG_CACHE_HOME:-$HOME/.cache}/ryoku/colors.json}"
target="$config_home/orgm-ryoku/rofi-colors.rasi"
fallback='{"surfaceContainer":"#1f1f25","surfaceContainerHigh":"#29292f","onSurface":"#e4e1e9","onSurfaceVariant":"#c7c5d0","primary":"#bcc3ff","primaryContainer":"#3b4279","onPrimaryContainer":"#dfe0ff","error":"#ffb4ab"}'
palette=$(jq -e 'select(type == "object")' "$colors" 2>/dev/null) || palette="$fallback"
mkdir -p "$(dirname "$target")"
tmp=$(mktemp "$target.XXXXXX")
trap 'rm -f "$tmp"' EXIT
jq -nr --argjson palette "$palette" --argjson fallback "$fallback" '
  def color(k):
    if ($palette[k] | type) != "string" then $fallback[k]
    elif ($palette[k] | test("^#[0-9a-fA-F]{6}$")) then $palette[k]
    else $fallback[k] end;
  "* {\n" +
  "    ryoku-bg: " + color("surfaceContainer") + "ee;\n" +
  "    ryoku-surface: " + color("surfaceContainerHigh") + ";\n" +
  "    ryoku-fg: " + color("onSurface") + ";\n" +
  "    ryoku-muted: " + color("onSurfaceVariant") + ";\n" +
  "    ryoku-accent: " + color("primary") + ";\n" +
  "    ryoku-selection: " + color("primaryContainer") + ";\n" +
  "    ryoku-selection-fg: " + color("onPrimaryContainer") + ";\n" +
  "    ryoku-error: " + color("error") + ";\n}"
' > "$tmp"
if [[ -f "$target" ]] && cmp -s "$tmp" "$target"; then
  exit 0
fi
chmod 0644 "$tmp"
mv -f -- "$tmp" "$target"
