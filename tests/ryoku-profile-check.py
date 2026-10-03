import json
import sys

def pam_rules(policies, service, phase):
    for line in policies[service].splitlines():
        fields = line.split()
        if not fields or fields[0] != phase:
            continue
        if fields[1] in {"include", "substack"}:
            yield from pam_rules(policies, fields[2], phase)
        else:
            yield fields[2:]

with open(sys.argv[1]) as source:
    inventory = json.load(source)
for host in ("lenovo", "orgm"):
    systems = inventory[host]
    normal = systems["normal"]
    assert normal["ryoku"] and normal["hyprland"] and normal["niri"], host
    assert normal["sddm"] and normal["theme"] == "ryoku" and not normal["lightdm"], host
    assert not normal["autoLogin"], host
    policies = {"sddm": normal["sddmPam"], "login": normal["loginPam"]}
    for service in policies:
        assert any(rule[0].endswith("/pam_gnome_keyring.so")
                   for rule in pam_rules(policies, service, "auth")), (host, service)
        assert any(rule[0].endswith("/pam_gnome_keyring.so") and "auto_start" in rule
                   for rule in pam_rules(policies, service, "session")), (host, service)
    assert not normal["ryokuLidOverride"], host
    assert "orgm-keyring-never-ask" not in normal["services"], host
    conflicting = (".config/kitty/", ".config/nvim/", ".config/waybar-hypr/", ".config/hypr/lua/")
    assert not any(path.startswith(conflicting) for path in normal["userFiles"]), host
    assert ".config/orgm-ryoku/osmarg-keybindings.lua" in normal["userFiles"], host
    assert "/users/osmarg/profiles/ryoku/" in normal["personalBindingsSource"], host
    assert normal["nautilusExtension"] and normal["nautilusTerminal"] == "kitty", host
    obsolete = {
        "night_mode_toggle", "night_mode_temp_up", "night_mode_temp_down", "check_night_mode",
        "clipboard_clear", "clipboard_delete_item", "clipboard_to_type", "clipboard_to_wlcopy",
        "record_screen_mp4", "record_screen_gif", "screenshot_edit", "screenshot_to_clipboard",
        "wlogout_uniqe", "unbindheadset", "fetch_music_player_data", "check_recording", "check_webcam",
        "wifi_toggle", "bluetooth_toggle", "airplane_mode_toggle", "reset_config",
        "hypr-rofi-calc", "hypr-rofi-open-file", "hypr-rofi-open-file-dir", "hypr-rofi-open-file-terminal",
        "hypr-kill-windows",
    }
    assert not {".local/bin/" + name for name in obsolete} & set(normal["userFiles"]), host
    assert {".local/bin/windows-rdp", ".local/bin/hypr-pi-prompt", ".local/bin/hypr-rofi-ssh-host",
            ".local/bin/hypr-video-timer"} <= set(normal["userFiles"]), host
    assert not {"external-lid-inhibit", "openrgb-notify"} & set(normal["homeServices"]), host
    assert {"ryoku-shell", "ryoku-materialize", "hypridle"} <= set(normal["services"]), host
    assert not normal["notificationDaemons"] and not normal["homeDunst"] and not normal["homeMako"], host
    assert ".local/bin/dunstify" in normal["userFiles"], host
    assert ".local/bin/dunst_pause" not in normal["userFiles"], host
    for name, configuration in systems["specialisations"].items():
        assert not configuration["failedAssertions"], (host, name, configuration["failedAssertions"])
        if name in {"server", "gaming"}:
            assert not configuration["nautilusExtension"], (host, name)
            assert not configuration["ryoku"] and not configuration["hyprland"] and not configuration["niri"], (host, name)
            assert not configuration["sddm"] and not configuration["lightdm"], (host, name)
            assert configuration["target"] == "multi-user.target", (host, name)
            assert not {"ryoku-shell", "ryoku-materialize"} & set(configuration["services"]), (host, name)
        else:
            assert not configuration["notificationDaemons"], (host, name)
    assert not normal["failedAssertions"], (host, normal["failedAssertions"])
assert set(inventory["lenovo"]["specialisations"]) == {"battery", "gaming", "server", "windows-vfio"}
assert inventory["lenovo"]["specialisations"]["windows-vfio"]["vfio"]
assert all(inventory["legacyNotifications"].values()), inventory["legacyNotifications"]
for configuration in [inventory["lenovo"]["normal"], *inventory["lenovo"]["specialisations"].values()]:
    assert all(configuration["lidPolicy"][key] == "ignore" for key in (
        "HandleLidSwitch", "HandleLidSwitchExternalPower", "HandleLidSwitchDocked"
    ))
print("PASS: Ryoku owns desktop/configs, preserves personal helpers, and retains every host boot mode")
