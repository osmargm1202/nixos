"""Merge only the X13 AI shortcut; preserve manually configured shortcuts."""
import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio

PATH = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/x13-orgmai/"
settings = Gio.Settings.new("org.gnome.settings-daemon.plugins.media-keys")
paths = settings.get_strv("custom-keybindings")
if PATH not in paths:
    settings.set_strv("custom-keybindings", paths + [PATH])
Gio.Settings.sync()
