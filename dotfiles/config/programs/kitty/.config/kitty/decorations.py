# Included by kitty.conf (geninclude): normal windows with buttons on GNOME,
# borderless everywhere else (Hyprland, i3, Sway...).
import os

if "GNOME" in os.environ.get("XDG_CURRENT_DESKTOP", "").upper().split(":"):
    print("hide_window_decorations no")
