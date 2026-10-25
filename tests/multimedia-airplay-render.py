"""Exercise the installed UxPlay GStreamer plugins in an isolated Sway session.

Usage: python3 tests/multimedia-airplay-render.py SYSTEM GST_BIN [--check-previous]
SYSTEM is the multimedia system store path; GST_BIN is gstreamer's bin output.
No Apple sender, network, audio or live session is involved in this regression.
"""

import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time


def windows(node):
    if node.get("app_id"):
        yield node
    for child in node.get("nodes", []) + node.get("floating_nodes", []):
        yield from windows(child)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("system", type=Path)
    parser.add_argument("gst_bin", type=Path)
    parser.add_argument("--check-previous", action="store_true")
    args = parser.parse_args()
    binaries = args.system.resolve() / "sw/bin"
    uxplay = (binaries / "uxplay").resolve().parent.parent
    closure = subprocess.check_output(["nix-store", "-qR", str(uxplay)], text=True)
    plugins = [str(Path(p) / "lib/gstreamer-1.0") for p in closure.splitlines()
               if (Path(p) / "lib/gstreamer-1.0").is_dir()]
    assert plugins, "UxPlay plugin closure is empty"
    root = Path(tempfile.mkdtemp(prefix="orgm-airplay-render-"))
    runtime = root / "runtime"
    runtime.mkdir(mode=0o700)
    env = {k: v for k, v in os.environ.items() if k not in {
        "SWAYSOCK", "WAYLAND_DISPLAY", "DISPLAY", "DBUS_SESSION_BUS_ADDRESS",
        "WAYLAND_SOCKET", "GST_PLUGIN_PATH", "GST_PLUGIN_PATH_1_0",
    }}
    env.update(XDG_RUNTIME_DIR=str(runtime), HOME=str(root),
               XDG_CONFIG_HOME=str(root / "config"), XDG_CACHE_HOME=str(root / "cache"),
               WLR_BACKENDS="headless", WLR_HEADLESS_OUTPUTS="1",
               WLR_RENDERER="pixman", WLR_LIBINPUT_NO_DEVICES="1",
               LIBGL_ALWAYS_SOFTWARE="1", GST_PLUGIN_SYSTEM_PATH_1_0=":".join(plugins))
    config = root / "sway.conf"
    config.write_text('output * mode 1920x1080\ndefault_border none\n'
                      'for_window [app_id="gst-launch-1.0"] fullscreen enable\n')
    print(f"Evidence: {root}", flush=True)
    with (root / "sway.log").open("w") as log:
        sway = subprocess.Popen([str(binaries / "sway"), "--config", str(config)],
                                env=env, stdout=log, stderr=log)
        try:
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline:
                sockets = list(runtime.glob("sway-ipc.*.sock"))
                displays = [p for p in runtime.glob("wayland-*") if p.is_socket()]
                if sockets and displays:
                    break
                assert sway.poll() is None, "Isolated Sway exited"
                time.sleep(0.1)
            assert sockets and displays, "Isolated Sway did not start"
            env.update(SWAYSOCK=str(sockets[0]), WAYLAND_DISPLAY=displays[0].name)
            cases = [("raw", []), ("h264", ["x264enc", "tune=zerolatency", "!",
                                            "h264parse", "!", "decodebin", "!"])]
            if args.check_previous:
                cases.insert(0, ("previous", []))
            for name, codec in cases:
                command = [str(args.gst_bin / "bin/gst-launch-1.0"), "-e",
                           "videotestsrc", "num-buffers=90", "!",
                           "video/x-raw,format=I420,width=640,height=360,framerate=30/1",
                           "!"] + codec + ["videoconvert", "!", "videoscale", "!", "waylandsink"]
                if name == "previous":
                    command.append("fullscreen=true")
                with (root / f"{name}.log").open("w") as gst_log:
                    process = subprocess.Popen(command, env=env, stdout=gst_log, stderr=gst_log)
                    try:
                        deadline = time.monotonic() + 12
                        while True:
                            tree = json.loads(subprocess.check_output(
                                [str(binaries / "swaymsg"), "-t", "get_tree", "-r"], env=env))
                            if any(w.get("pid") == process.pid for w in windows(tree)):
                                break
                            if process.poll() is not None or time.monotonic() >= deadline:
                                break
                            time.sleep(0.1)
                        (root / f"{name}-tree.json").write_text(json.dumps(tree))
                        code = process.wait(timeout=15)
                    finally:
                        if process.poll() is None:
                            process.terminate()
                            process.wait(timeout=5)
                output = (root / f"{name}.log").read_text()
                if name == "previous":
                    assert code != 0 and "Window has no size set" in output, output
                else:
                    assert code == 0 and "Got EOS" in output and "ERROR" not in output, output
                    rendered = [w for w in windows(tree) if w.get("pid") == process.pid]
                    assert len(rendered) == 1, tree
                    window = rendered[0]
                    assert window["fullscreen_mode"] == 1, window
                    assert (window["rect"]["width"], window["rect"]["height"]) == (1920, 1080), window
                print(f"PASS {name}", flush=True)
        finally:
            sway.terminate()
            sway.wait(timeout=5)


if __name__ == "__main__":
    main()
