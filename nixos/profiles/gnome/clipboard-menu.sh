set -euo pipefail
if result=$(gdbus call --session --dest org.gnome.Shell \
  --object-path /org/orgm/DesktopMenus \
  --method org.orgm.DesktopMenus.ShowClipboard 2>/dev/null) && [[ "$result" == '(true,)' ]]; then
  exit 0
fi
notify-send Portapapeles 'Abre Clipboard Indicator en la barra superior. Si acabas de actualizar, vuelve a iniciar sesión para activar la integración.'
exit 1
