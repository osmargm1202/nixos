#!/usr/bin/env python3
"""Exercise bundled plugins and animation presets in an isolated nested session.

Requires a running Wayland desktop. Never edits its configuration or imports
any nested display variables into the user's systemd/D-Bus environment.
"""
from pathlib import Path
import json
import os
import signal
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
expr = '''let f=builtins.getFlake ("path:"+builtins.getEnv "RYOKU_TEST_REPO");
  p=(import (builtins.getEnv "RYOKU_TEST_REPO"+"/nixos/profiles/ryoku/provider-compat.nix")
    {inputs=f.inputs;pkgs=f.nixosConfigurations.lenovo.pkgs;lib=f.inputs.nixpkgs.lib;}).packages;
  in f.nixosConfigurations.lenovo.pkgs.writeText "ryoku-session-test.json" (builtins.toJSON {
    compositor=toString p.ryoku-hyprland; provider=toString p.ryoku-wm-hyprland;
    plugins=toString p.ryoku-hypr-plugins; data=toString p.ryoku-desktop-data;
    hub=toString p.ryoku-hub; kitty=toString f.nixosConfigurations.lenovo.pkgs.kitty;
  })'''
manifest = subprocess.check_output(
    ["nix", "build", "--impure", "--no-link", "--print-out-paths", "--expr", expr],
    env=dict(os.environ, RYOKU_TEST_REPO=str(ROOT)), text=True).strip()
packages = json.loads(Path(manifest).read_text())
parent_display = Path(os.environ["XDG_RUNTIME_DIR"]) / os.environ["WAYLAND_DISPLAY"]

# Short runtime paths are required by the Unix socket path length limit.
with tempfile.TemporaryDirectory(prefix="rp-") as tmp:
    home = Path(tmp)
    runtime = home/"r"
    runtime.mkdir(mode=0o700)
    cfg = home/".config"
    hypr = cfg/"hypr"
    hypr.mkdir(parents=True)
    (cfg/"ryoku").mkdir()
    data = Path(packages["data"])/"share/ryoku/config/hypr"
    (hypr/"modules").symlink_to(data/"modules", target_is_directory=True)
    config = hypr/"hyprland.lua"
    config.write_text(
        f'package.path = {json.dumps(str(hypr)+"/?.lua;")} .. package.path\n'
        'hl.monitor({output="",mode="1280x720@60",position="0x0",scale=1})\n'
        'hl.config({debug={disable_logs=false},animations={enabled=true}})\n'
        'require("modules.animations")\n'
        f'dofile({json.dumps(str(hypr/"settings.lua"))})\n')
    store = cfg/"ryoku/desktop.json"
    plugin_settings = {name: {"enabled": True} for name in (
        "dynamicCursors", "hyprglass", "hyprbars", "hyprfocus", "imgborders", "keysounds")}
    plugin_settings["hyprfocus"]["mouse"] = True
    store.write_text(json.dumps({
        "desktop": {"appearance": {"animations": True, "windowStyle": "preset"}},
        "wm": {"hyprland": {"plugins": plugin_settings}},
    }))
    env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(cfg),
        XDG_CACHE_HOME=str(home/".cache"), XDG_DATA_HOME=str(home/".local/share"),
        XDG_STATE_HOME=str(home/".local/state"), XDG_RUNTIME_DIR=str(runtime),
        WAYLAND_DISPLAY=str(parent_display), AQ_DRM_DEVICES="/dev/null",
        HYPRLAND_NO_SD_VARS="1", HYPRLAND_NO_SD_NOTIFY="1", HYPRLAND_NO_RT="1",
        DBUS_SESSION_BUS_ADDRESS="unix:path="+str(runtime/"no-session-bus"),
        RYOKU_WM="hyprland", PATH=packages["provider"]+"/bin:"+os.environ["PATH"])
    env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)
    env.pop("WAYLAND_SOCKET", None)
    provider = packages["provider"]+"/bin/ryoku-wm-hyprland"
    compositor = packages["compositor"]+"/bin/Hyprland"
    hyprctl = packages["compositor"]+"/bin/hyprctl"

    def command(argv, check=True):
        return subprocess.run(argv, env=env, capture_output=True, text=True,
                              timeout=15, check=check)

    def ctl(*args):
        return command([hyprctl, *args]).stdout.strip()

    def loaded_names():
        return {row["name"] for row in json.loads(ctl("plugin", "list", "-j"))}

    wanted = {"dynamic-cursors", "hyprglass", "hyprbars", "hyprfocus", "imgborders", "keysounds"}
    command([provider, "apply", str(store)])
    log = (home/"compositor.log").open("w+")
    child = subprocess.Popen([compositor, "--config", str(config)], env=env,
        stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
    clients = []

    def open_window():
        before = len(json.loads(ctl("clients", "-j")))
        client_env = dict(env, WAYLAND_DISPLAY=json.loads(ctl("instances", "-j"))[0]["wl_socket"])
        client = subprocess.Popen([packages["kitty"]+"/bin/kitty", "--config", "NONE",
            "--class", "ryoku-plugin-test", "-o", "linux_display_server=wayland",
            "-o", "sync_to_monitor=no", "sh", "-c", "sleep 600"],
            env=client_env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        clients.append(client)
        for _ in range(100):
            assert child.poll() is None, "compositor crashed while opening a window"
            if len(json.loads(ctl("clients", "-j"))) > before:
                return
            time.sleep(0.05)
        raise AssertionError("test window did not open")
    try:
        ready = False
        for _ in range(150):
            sockets = list(runtime.glob("hypr/*/.socket.sock"))
            if sockets:
                env["HYPRLAND_INSTANCE_SIGNATURE"] = sockets[0].parent.name
                result = command([hyprctl, "monitors", "-j"], check=False)
                if result.returncode == 0 and result.stdout.strip().startswith("["):
                    ready = bool(json.loads(result.stdout))
                    if ready:
                        break
            if child.poll() is not None:
                break
            time.sleep(0.1)
        assert ready, "nested compositor failed to become ready"
        # First config pass declares the plugins. The following pass applies
        # their options after the loader has registered their config keys.
        ctl("reload", "config-only")
        command([provider, "plugins", "sync"])
        assert loaded_names() == wanted, loaded_names()
        assert not ctl("configerrors"), ctl("configerrors")
        assert "flash" in ctl("getoption", "plugin:hyprfocus:mouse_focus_animation")
        assert "ryoku-hub" in ctl("getoption", "plugin:hyprglass:default_preset")
        open_window()

        # Exercise the actual Hub backend and compositor, not a Lua mock.
        fingerprints = set()
        presets = sorted(p.stem for p in (data/"modules/animations").glob("*.lua"))
        for preset in presets:
            command([packages["hub"]+"/bin/ryoku-hub", "desktop", "anim-preset", preset])
            assert not ctl("configerrors"), (preset, ctl("configerrors"))
            enabled = json.loads(ctl("getoption", "animations:enabled", "-j"))["bool"]
            assert enabled == (preset != "disable"), (preset, enabled)
            animations = json.loads(ctl("animations", "-j"))[0]
            fingerprints.add(json.dumps(animations, sort_keys=True))
            assert loaded_names() == wanted, (preset, loaded_names())
        assert len(fingerprints) > 5, "preset selections did not change the compositor"

        # Reload and unload/reload must not reuse another plugin's state.
        saved = json.loads(store.read_text())
        for options in saved["wm"]["hyprland"]["plugins"].values():
            if isinstance(options, dict):
                options["enabled"] = False
        store.write_text(json.dumps(saved))
        command([provider, "apply", str(store)])
        ctl("reload", "config-only")
        command([provider, "plugins", "sync"])
        assert not loaded_names(), loaded_names()
        assert not ctl("configerrors"), ctl("configerrors")
        # An unloaded DSO may remain resident. Its callbacks must no longer
        # run after PluginAPI has removed its configuration values.
        open_window()
        for options in saved["wm"]["hyprland"]["plugins"].values():
            if isinstance(options, dict):
                options["enabled"] = True
        store.write_text(json.dumps(saved))
        command([provider, "apply", str(store)])
        ctl("reload", "config-only")
        command([provider, "plugins", "sync"])
        assert loaded_names() == wanted, loaded_names()
        open_window()
        assert not ctl("configerrors"), ctl("configerrors")
        print(f"PASS: six plugins, {len(presets)} presets, windows before/after unload and reload")
    except Exception:
        log.seek(0)
        print(log.read()[-4000:])
        for log_path in runtime.glob("hypr/*/hyprland.log"):
            print(log_path.read_text(errors="replace")[-8000:])
        raise
    finally:
        for client in clients:
            if client.poll() is None:
                os.killpg(client.pid, signal.SIGTERM)
            client.wait(timeout=3)
        if child.poll() is None:
            try:
                command([hyprctl, "dispatch", "exit"], check=False)
            except (OSError, subprocess.TimeoutExpired):
                pass
        try:
            child.wait(timeout=3)
        except subprocess.TimeoutExpired:
            os.killpg(child.pid, signal.SIGKILL)
            child.wait()
        # Hyprland's crash reporter may fork into a separate session. Limit
        # cleanup to processes with this exact disposable config argument.
        for proc in Path("/proc").iterdir():
            if not proc.name.isdigit():
                continue
            try:
                args = (proc/"cmdline").read_bytes().split(b"\0")
                if str(config).encode() in args:
                    os.kill(int(proc.name), signal.SIGKILL)
            except (OSError, ProcessLookupError):
                pass
        log.close()
