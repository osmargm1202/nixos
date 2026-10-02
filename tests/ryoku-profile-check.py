import json
import sys

with open(sys.argv[1]) as source:
    inventory = json.load(source)
for host in ("lenovo", "orgm"):
    systems = inventory[host]
    normal = systems["normal"]
    assert normal["ryoku"] and normal["hyprland"] and normal["niri"], host
    assert normal["sddm"] and normal["theme"] == "ryoku" and not normal["lightdm"], host
    assert normal["keyringPolicy"] == "never-ask" and not normal["keyringPam"], host
    conflicting = (".config/kitty/", ".config/nvim/", ".config/waybar-hypr/", ".config/hypr/lua/")
    assert not any(path.startswith(conflicting) for path in normal["userFiles"]), host
    assert ".config/orgm-ryoku/osmarg-keybindings.lua" in normal["userFiles"], host
    assert not {"external-lid-inhibit", "openrgb-notify"} & set(normal["homeServices"]), host
    assert {"ryoku-shell", "ryoku-materialize", "hypridle", "orgm-keyring-never-ask"} <= set(normal["services"]), host
    for name, configuration in systems["specialisations"].items():
        assert not configuration["failedAssertions"], (host, name, configuration["failedAssertions"])
        if name in {"server", "gaming"}:
            assert not configuration["ryoku"] and not configuration["hyprland"] and not configuration["niri"], (host, name)
            assert not configuration["sddm"] and not configuration["lightdm"], (host, name)
            assert configuration["target"] == "multi-user.target", (host, name)
            assert not {"ryoku-shell", "ryoku-materialize"} & set(configuration["services"]), (host, name)
    assert not normal["failedAssertions"], (host, normal["failedAssertions"])
assert set(inventory["lenovo"]["specialisations"]) == {"battery", "gaming", "server", "windows-vfio"}
assert inventory["lenovo"]["specialisations"]["windows-vfio"]["vfio"]
print("PASS: Ryoku owns desktop/configs, preserves personal helpers, and retains every host boot mode")
