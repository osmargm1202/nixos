#!/usr/bin/env python3
"""GTK4 wallpaper picker backed by orgm-wallpaper."""
from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import subprocess
import sys
from dataclasses import dataclass
from typing import Any

APP_ID = "org.orgm.HyprWallpaperPicker"
BACKEND = "orgm-wallpaper"
DEFAULT_STATIC_DIR = pathlib.Path.home() / "Pictures" / "Wallpapers"
DEFAULT_VIDEO_DIR = pathlib.Path.home() / "Videos" / "wallpapers"
STATE_DIR = pathlib.Path(os.environ.get("XDG_STATE_HOME", pathlib.Path.home() / ".local" / "state")) / "hypr-wallpaper"
PICKER_JSON = STATE_DIR / "wallpaper-picker.json"
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp"}
VIDEO_EXTS = {".mp4", ".mkv", ".webm", ".mov", ".avi", ".m4v"}

THEMES = {
    "dark": {
        "PANEL_BG": "00000099",
        "TEXT": "cad3f5",
        "BLUE": "8aadf4",
        "MAUVE": "c6a0f6",
        "SURFACE0": "363a4f",
    },
    "light": {
        "PANEL_BG": "ffffffff",
        "TEXT": "111827",
        "BLUE": "0057d9",
        "MAUVE": "8839ef",
        "SURFACE0": "d1d5db",
    },
}


@dataclass(frozen=True)
class WallpaperItem:
    path: str
    name: str
    thumb: str | None = None


@dataclass(frozen=True)
class Monitor:
    output: str
    label: str


@dataclass(frozen=True)
class PickerData:
    tabs: dict[str, list[WallpaperItem]]
    monitors: list[Monitor]


def hex_to_css(value: str) -> str:
    value = value.strip().lstrip("#")
    if len(value) == 8:
        r, g, b, a = value[0:2], value[2:4], value[4:6], value[6:8]
        return f"rgba({int(r, 16)}, {int(g, 16)}, {int(b, 16)}, {int(a, 16) / 255:.3f})"
    if len(value) == 6:
        return f"#{value}"
    return value


def infer_thumb(path: pathlib.Path) -> str | None:
    thumb_dir = path.parent / ".thumb"
    candidates = [
        thumb_dir / path.name,
        thumb_dir / f"{path.name}.png",
        thumb_dir / f"{path.stem}.png",
        thumb_dir / f"{path.stem}.jpg",
        thumb_dir / f"{path.stem}.webp",
    ]
    for candidate in candidates:
        if candidate.exists():
            return str(candidate)
    return None


def scan_wallpapers(directory: pathlib.Path | str, exts: set[str] | None = None) -> list[WallpaperItem]:
    base = pathlib.Path(directory).expanduser()
    if not base.exists():
        return []
    allowed = exts or (IMAGE_EXTS | VIDEO_EXTS)
    items: list[WallpaperItem] = []
    for path in sorted(base.iterdir(), key=lambda p: p.name.lower()):
        if path.is_file() and path.suffix.lower() in allowed:
            items.append(WallpaperItem(path=str(path), name=path.name, thumb=infer_thumb(path)))
    return items


def _item_from_payload(raw: Any) -> WallpaperItem | None:
    if isinstance(raw, str):
        path = raw
        return WallpaperItem(path=path, name=pathlib.Path(path).name, thumb=infer_thumb(pathlib.Path(path)))
    if not isinstance(raw, dict):
        return None
    path = raw.get("path") or raw.get("file") or raw.get("source") or raw.get("wallpaper")
    if not path:
        return None
    name = raw.get("name") or raw.get("label") or pathlib.Path(path).name
    thumb = raw.get("thumb") or raw.get("thumbnail") or raw.get("preview") or infer_thumb(pathlib.Path(path))
    return WallpaperItem(path=str(path), name=str(name), thumb=str(thumb) if thumb else None)


def _items_from_tab(raw_tab: Any) -> list[WallpaperItem]:
    if isinstance(raw_tab, dict):
        raw_items = raw_tab.get("items", [])
    else:
        raw_items = raw_tab or []
    items = []
    for raw in raw_items:
        item = _item_from_payload(raw)
        if item:
            items.append(item)
    return items


def _monitor_from_payload(raw: Any) -> Monitor | None:
    if isinstance(raw, str):
        return Monitor(output=raw, label=raw)
    if not isinstance(raw, dict):
        return None
    output = raw.get("output") or raw.get("name") or raw.get("id")
    if not output:
        return None
    desc = raw.get("description") or raw.get("make") or raw.get("model") or output
    label = output if desc == output else f"{output} — {desc}"
    return Monitor(output=str(output), label=str(label))


def load_picker_json_from_payload(payload: dict[str, Any]) -> PickerData:
    tabs_payload = payload.get("tabs", {}) if isinstance(payload, dict) else {}
    tabs = {
        "static": _items_from_tab(tabs_payload.get("static", [])),
        "video": _items_from_tab(tabs_payload.get("video", [])),
    }
    monitors = []
    for raw in payload.get("monitors", []) if isinstance(payload, dict) else []:
        monitor = _monitor_from_payload(raw)
        if monitor:
            monitors.append(monitor)
    return PickerData(tabs=tabs, monitors=monitors)


def load_picker_json(path: pathlib.Path = PICKER_JSON) -> PickerData | None:
    try:
        with path.expanduser().open("r", encoding="utf-8") as handle:
            payload = json.load(handle)
        return load_picker_json_from_payload(payload)
    except FileNotFoundError:
        return None
    except (OSError, json.JSONDecodeError) as exc:
        print(f"warning: could not read {path}: {exc}", file=sys.stderr)
        return None


def load_hyprctl_monitors() -> list[Monitor]:
    try:
        proc = subprocess.run(["hyprctl", "-j", "monitors"], check=False, text=True, capture_output=True, timeout=3)
    except (OSError, subprocess.SubprocessError):
        return []
    if proc.returncode != 0:
        return []
    try:
        payload = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return []
    monitors = []
    for raw in payload if isinstance(payload, list) else []:
        monitor = _monitor_from_payload(raw)
        if monitor:
            monitors.append(monitor)
    return monitors


def load_data() -> PickerData:
    data = load_picker_json()
    if data:
        monitors = data.monitors or load_hyprctl_monitors()
        return PickerData(tabs=data.tabs, monitors=monitors)
    return PickerData(
        tabs={
            "static": scan_wallpapers(DEFAULT_STATIC_DIR, IMAGE_EXTS),
            "video": scan_wallpapers(DEFAULT_VIDEO_DIR, VIDEO_EXTS),
        },
        monitors=load_hyprctl_monitors(),
    )


def build_backend_command(command: str, path: str | None = None, monitor: str | None = None) -> list[str]:
    args = [BACKEND, command]
    if path:
        args.append(path)
    if monitor:
        args.extend(["--monitor", monitor])
    return args


def run_backend(command: str, path: str | None = None, monitor: str | None = None) -> subprocess.CompletedProcess[str] | None:
    try:
        return subprocess.run(build_backend_command(command, path, monitor), check=False, text=True, capture_output=True, timeout=20)
    except (OSError, subprocess.SubprocessError) as exc:
        print(f"warning: backend command failed to start: {exc}", file=sys.stderr)
        return None


def warm_page(kind: str, page: int, page_size: int) -> None:
    try:
        subprocess.Popen([BACKEND, "warm-page", kind, str(page), str(page_size)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        pass


def parse_status_current(output: str) -> str | None:
    text = output.strip()
    if not text:
        return None
    try:
        payload = json.loads(text)
        if isinstance(payload, dict):
            for key in ("current", "path", "wallpaper", "file"):
                if payload.get(key):
                    return str(payload[key])
            for value in payload.values():
                if isinstance(value, dict):
                    nested = parse_status_current(json.dumps(value))
                    if nested:
                        return nested
    except json.JSONDecodeError:
        pass
    match = re.search(r"(/[^\n\r]+?\.(?:jpg|jpeg|png|webp|gif|mp4|mkv|webm|mov|avi|m4v))", text, re.IGNORECASE)
    return match.group(1) if match else None


def css_for_theme(name: str) -> str:
    palette = THEMES[name]
    bg = hex_to_css(palette["PANEL_BG"])
    text = hex_to_css(palette["TEXT"])
    blue = hex_to_css(palette["BLUE"])
    mauve = hex_to_css(palette["MAUVE"])
    surface = hex_to_css(palette["SURFACE0"])
    return f"""
    * {{ font-family: 'JetBrainsMono Nerd Font', monospace; font-size: 12px; }}
    window {{ background: transparent; color: {text}; }}
    .root {{ background: {bg}; color: {text}; border: 2px solid {surface}; border-radius: 12px; padding: 12px; }}
    button, combobox, spinbutton {{ border-radius: 12px; border: 2px solid {surface}; background: transparent; color: {text}; padding: 6px; }}
    button:hover {{ border-color: {blue}; }}
    button.suggested-action {{ background: {blue}; color: #ffffff; }}
    button.accent {{ border-color: {mauve}; }}
    .card {{ border: 2px solid {surface}; border-radius: 12px; padding: 8px; background: alpha({surface}, 0.18); }}
    .card.current {{ border-color: {mauve}; }}
    .title {{ font-weight: 700; }}
    .muted {{ opacity: 0.72; }}
    """


def resolve_theme(theme: str) -> str:
    if theme != "auto":
        return theme
    return "light" if os.environ.get("COLOR_SCHEME") == "prefer-light" else "dark"


class WallpaperPickerApp:
    def __init__(self, args: argparse.Namespace) -> None:
        import gi

        gi.require_version("Gtk", "4.0")
        from gi.repository import Gdk, Gio, Gtk, Pango

        self.Gdk = Gdk
        self.Gio = Gio
        self.Gtk = Gtk
        self.Pango = Pango
        self.args = args
        self.theme = resolve_theme(args.theme)
        self.page_size = args.page_size
        self.data = load_data()
        self.active_tab = "static"
        self.pages = {"static": 0, "video": 0}
        self.current_path: str | None = None
        self.monitor: str | None = args.monitor
        self.grid = None
        self.status_label = None
        self.page_label = None
        self.monitor_combo = None
        self.window = None

    def run(self) -> int:
        app = self.Gtk.Application(application_id=APP_ID, flags=self.Gio.ApplicationFlags.DEFAULT_FLAGS)
        app.connect("activate", self.on_activate)
        return app.run([])

    def on_activate(self, app: Any) -> None:
        self.refresh_status()
        provider = self.Gtk.CssProvider()
        provider.load_from_data(css_for_theme(self.theme).encode())
        self.Gtk.StyleContext.add_provider_for_display(self.Gdk.Display.get_default(), provider, self.Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        self.window = self.Gtk.ApplicationWindow(application=app, title="ORGM Wallpaper Picker")
        self.window.set_default_size(980, 720)
        root = self.Gtk.Box(orientation=self.Gtk.Orientation.VERTICAL, spacing=10)
        root.add_css_class("root")
        self.window.set_child(root)

        header = self.Gtk.Box(orientation=self.Gtk.Orientation.HORIZONTAL, spacing=8)
        root.append(header)
        title = self.Gtk.Label(label="ORGM Wallpaper Picker")
        title.add_css_class("title")
        header.append(title)
        header.append(self.Gtk.Label(hexpand=True))
        self.monitor_combo = self.Gtk.ComboBoxText()
        self.monitor_combo.append("", "Global")
        for monitor in self.data.monitors:
            self.monitor_combo.append(monitor.output, monitor.label)
        self.monitor_combo.set_active_id(self.monitor or "")
        self.monitor_combo.connect("changed", self.on_monitor_changed)
        header.append(self.monitor_combo)

        switcher = self.Gtk.Box(orientation=self.Gtk.Orientation.HORIZONTAL, spacing=8)
        root.append(switcher)
        for tab in ("static", "video"):
            button = self.Gtk.Button(label=tab.title())
            button.connect("clicked", self.on_tab_clicked, tab)
            switcher.append(button)
        random_button = self.Gtk.Button(label="Random")
        random_button.add_css_class("accent")
        random_button.connect("clicked", self.on_random_clicked)
        switcher.append(random_button)

        scroller = self.Gtk.ScrolledWindow(vexpand=True)
        self.grid = self.Gtk.FlowBox(max_children_per_line=5, selection_mode=self.Gtk.SelectionMode.NONE)
        self.grid.set_row_spacing(10)
        self.grid.set_column_spacing(10)
        scroller.set_child(self.grid)
        root.append(scroller)

        footer = self.Gtk.Box(orientation=self.Gtk.Orientation.HORIZONTAL, spacing=8)
        root.append(footer)
        prev_button = self.Gtk.Button(label="← Previous")
        prev_button.connect("clicked", self.on_page_delta, -1)
        footer.append(prev_button)
        self.page_label = self.Gtk.Label(label="")
        footer.append(self.page_label)
        next_button = self.Gtk.Button(label="Next →")
        next_button.connect("clicked", self.on_page_delta, 1)
        footer.append(next_button)
        footer.append(self.Gtk.Label(hexpand=True))
        self.status_label = self.Gtk.Label(label="")
        self.status_label.add_css_class("muted")
        footer.append(self.status_label)

        self.render_page()
        self.window.present()

    def selected_monitor(self) -> str | None:
        if self.monitor_combo:
            value = self.monitor_combo.get_active_id()
            return value or None
        return self.monitor

    def on_monitor_changed(self, combo: Any) -> None:
        self.monitor = combo.get_active_id() or None
        self.refresh_status()
        self.render_page()

    def on_tab_clicked(self, _button: Any, tab: str) -> None:
        self.active_tab = tab
        self.render_page()

    def on_page_delta(self, _button: Any, delta: int) -> None:
        total = len(self.data.tabs.get(self.active_tab, []))
        max_page = max(0, (total - 1) // self.page_size)
        self.pages[self.active_tab] = min(max(self.pages[self.active_tab] + delta, 0), max_page)
        self.render_page()

    def on_random_clicked(self, _button: Any) -> None:
        command = "random-static" if self.active_tab == "static" else "random-video"
        result = run_backend(command, monitor=self.selected_monitor())
        self.show_result(result)
        self.refresh_status()
        self.render_page()

    def on_apply_clicked(self, _button: Any, item: WallpaperItem) -> None:
        command = "set-static" if self.active_tab == "static" else "set-video"
        result = run_backend(command, item.path, self.selected_monitor())
        self.show_result(result)
        self.refresh_status()
        self.render_page()

    def show_result(self, result: subprocess.CompletedProcess[str] | None) -> None:
        if not self.status_label:
            return
        if result is None:
            self.status_label.set_label("Backend unavailable")
        elif result.returncode == 0:
            self.status_label.set_label("Applied")
        else:
            msg = (result.stderr or result.stdout or "Backend failed").strip().splitlines()[0]
            self.status_label.set_label(msg[:160])

    def refresh_status(self) -> None:
        result = run_backend("status", monitor=self.selected_monitor())
        if result and result.returncode == 0:
            self.current_path = parse_status_current(result.stdout)

    def render_page(self) -> None:
        if not self.grid:
            return
        while child := self.grid.get_first_child():
            self.grid.remove(child)
        items = self.data.tabs.get(self.active_tab, [])
        page = self.pages[self.active_tab]
        start = page * self.page_size
        shown = items[start : start + self.page_size]
        warm_page(self.active_tab, page, self.page_size)
        for item in shown:
            self.grid.append(self.card_for_item(item))
        total_pages = max(1, (len(items) + self.page_size - 1) // self.page_size)
        if self.page_label:
            self.page_label.set_label(f"Page {page + 1} / {total_pages} · {len(items)} items")
        if self.status_label and self.current_path:
            self.status_label.set_label(f"Current: {pathlib.Path(self.current_path).name}")

    def card_for_item(self, item: WallpaperItem) -> Any:
        box = self.Gtk.Box(orientation=self.Gtk.Orientation.VERTICAL, spacing=6)
        box.add_css_class("card")
        if self.current_path and pathlib.Path(item.path) == pathlib.Path(self.current_path):
            box.add_css_class("current")
        image_path = item.thumb or item.path
        picture = self.Gtk.Picture.new_for_filename(image_path) if image_path and pathlib.Path(image_path).exists() else self.Gtk.Picture()
        picture.set_size_request(160, 100)
        picture.set_content_fit(self.Gtk.ContentFit.COVER)
        box.append(picture)
        label = self.Gtk.Label(label=item.name, ellipsize=self.Pango.EllipsizeMode.END)
        box.append(label)
        button = self.Gtk.Button(label="Apply")
        button.add_css_class("suggested-action")
        button.connect("clicked", self.on_apply_clicked, item)
        box.append(button)
        return box


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="GTK4 wallpaper picker backed by orgm-wallpaper")
    parser.add_argument("--theme", choices=["dark", "light", "auto"], default="auto")
    parser.add_argument("--page-size", type=int, default=20)
    parser.add_argument("--monitor", help="Hyprland output name; omit for global")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    if args.page_size < 1:
        raise SystemExit("--page-size must be >= 1")
    return WallpaperPickerApp(args).run()


if __name__ == "__main__":
    raise SystemExit(main())
