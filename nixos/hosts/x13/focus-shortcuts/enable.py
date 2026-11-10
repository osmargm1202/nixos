"""Merge the X13 extension selection at graphical login, never restart Shell."""
import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio

UUID = "x13-focus-shortcuts@orgm.local"
INCOMPATIBLE = "gnome-ui-tune@itstime.tech"
settings = Gio.Settings.new("org.gnome.shell")
enabled = settings.get_strv("enabled-extensions")
wanted = [uuid for uuid in enabled if uuid != INCOMPATIBLE]
if UUID not in wanted:
    wanted.append(UUID)
if wanted != enabled:
    settings.set_strv("enabled-extensions", wanted)
disabled = settings.get_strv("disabled-extensions")
if UUID in disabled:
    settings.set_strv("disabled-extensions", [uuid for uuid in disabled if uuid != UUID])
Gio.Settings.sync()
