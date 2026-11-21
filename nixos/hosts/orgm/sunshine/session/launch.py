"""Run a Sunshine application and present the loading screen until it is ready."""

import os
from pathlib import Path
import signal
import subprocess
import sys
from threading import Event
from time import monotonic, sleep

from focus import STEAM_ID, application_window, i3, window_rule, windows


ASSET = Path(__file__).with_name("loading.png")
SPLASH_TITLE = "orgm-moonlight-loading"
START_TIMEOUT = 60
STEAM_KEYS = (b"SteamAppId=", b"SteamGameId=")
PROC = Path("/proc")


def tagged(proc, app_id):
    try:
        if proc.stat().st_uid == os.getuid():
            values = (proc / "environ").read_bytes().split(b"\0")
            return any(key + app_id.encode() in values for key in STEAM_KEYS)
    except OSError:
        pass
    return False


def steam_processes(app_id):
    return {int(proc.name) for proc in PROC.iterdir()
            if proc.name.isdecimal() and tagged(proc, app_id)}


def signal_steam(app_id, baseline, sig):
    for pid in steam_processes(app_id) - baseline:
        try:
            descriptor = os.pidfd_open(pid)
        except ProcessLookupError:
            continue
        try:
            if tagged(PROC / str(pid), app_id):
                signal.pidfd_send_signal(descriptor, sig)
        except ProcessLookupError:
            pass
        finally:
            os.close(descriptor)


def find_window(rule):
    if os.environ.get("XDG_CURRENT_DESKTOP") != "i3" or rule is None:
        return None
    try:
        return application_window(windows(i3("-t", "get_tree")), rule)
    except (OSError, ValueError, subprocess.SubprocessError):
        return None


def show_splash():
    if os.environ.get("XDG_CURRENT_DESKTOP") != "i3" or not ASSET.is_file():
        return None
    try:
        return subprocess.Popen([
            "mpv", "--no-config", "--vo=x11", "--fullscreen", "--panscan=1",
            "--image-display-duration=inf", "--no-input-default-bindings",
            "--no-input-cursor", "--no-input-terminal", "--no-osc", "--no-audio",
            "--really-quiet", f"--title={SPLASH_TITLE}", ASSET,
        ])
    except OSError as exc:
        print(f"Sunshine loading screen: {exc}", file=sys.stderr, flush=True)
        return None


def stop_process(process):
    if process is not None and process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()


def close_window(window):
    if window is not None:
        try:
            i3(f'[con_id={int(window["id"])}] kill')
        except (OSError, ValueError, subprocess.SubprocessError):
            pass


def stop_steam(app_id, baseline, rule):
    if not (steam_processes(app_id) - baseline):
        return
    # A close request lets the game handle save/exit before sending signals.
    if not baseline:
        close_window(find_window(rule))
    for sig in (signal.SIGTERM, signal.SIGKILL):
        for _ in range(12):
            if not (steam_processes(app_id) - baseline):
                return
            sleep(0.25)
        signal_steam(app_id, baseline, sig)


def supervise(command):
    uri = command[1] if len(command) > 1 and Path(command[0]).name == "steam" else ""
    match = STEAM_ID.fullmatch(uri)
    app_id = match[1] if match else None
    big_picture = uri == "steam://open/bigpicture"
    steam = app_id is not None or big_picture
    baseline = steam_processes(app_id) if app_id else set()
    rule = window_rule({
        "name": os.environ.get("SUNSHINE_APP_NAME", Path(command[0]).stem),
        "cmd": subprocess.list2cmdline(command),
    })
    stop = Event()
    signal.signal(signal.SIGTERM, lambda *_: stop.set())
    signal.signal(signal.SIGINT, lambda *_: stop.set())
    splash = show_splash()
    child = None
    seen = bool(baseline)
    deadline = monotonic() + START_TIMEOUT
    try:
        child = subprocess.Popen(command, start_new_session=steam)
        while not stop.is_set():
            if not steam and child.poll() is not None:
                return child.returncode
            window = find_window(rule) if splash is not None or big_picture else None
            if splash is not None and (window is not None or monotonic() >= deadline):
                stop_process(splash)
                splash = None
                if window is not None:
                    try:
                        i3(f'[con_id={int(window["id"])}] focus')
                    except (OSError, ValueError, subprocess.SubprocessError):
                        pass
            if steam:
                running = bool(steam_processes(app_id)) if app_id else window is not None
                if not running and (seen or monotonic() >= deadline):
                    return child.poll() or 0
                seen = seen or running
            stop.wait(.35 if splash is not None else 1)
        if app_id:
            stop_steam(app_id, baseline, rule)
        elif not steam:
            if child.poll() is None:
                try:
                    child.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    stop_process(child)
        return 0
    finally:
        stop_process(splash)


if __name__ == "__main__":
    sys.exit(supervise(sys.argv[1:]))
