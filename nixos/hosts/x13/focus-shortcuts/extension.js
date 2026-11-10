import Gio from 'gi://Gio';
import Shell from 'gi://Shell';
import Meta from 'gi://Meta';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const apps = {
    console: 'org.gnome.Console.desktop',
    firefox: 'brave-origin.desktop',
    files: 'org.gnome.Nautilus.desktop',
};

export default class FocusShortcuts extends Extension {
    enable() {
        this._clipboard = Gio.DBusExportedObject.wrapJSObject(
            '<node><interface name="org.orgm.DesktopMenus">' +
            '<method name="ShowClipboard"><arg type="b" direction="out"/></method>' +
            '</interface></node>', this);
        this._clipboard.export(Gio.DBus.session, '/org/orgm/DesktopMenus');
        const settings = this.getSettings();
        for (const [name, desktopId] of Object.entries(apps)) {
            Main.wm.addKeybinding(name, settings, Meta.KeyBindingFlags.NONE,
                Shell.ActionMode.NORMAL, () => {
                    const app = Shell.AppSystem.get_default().lookup_app(desktopId);
                    if (!app)
                        return;
                    const windows = app.get_windows();
                    windows.sort((a, b) => b.get_user_time() - a.get_user_time());
                    if (windows.length)
                        Main.activateWindow(windows[0]);
                    else if (app.get_state() !== Shell.AppState.STARTING)
                        app.activate();
                });
        }
    }

    ShowClipboard() {
        if (Main.sessionMode.isLocked || Main.sessionMode.isGreeter)
            return false;
        const indicator = Main.panel.statusArea.clipboardIndicator;
        if (!indicator?.menu)
            return false;
        indicator.menu.open();
        return true;
    }

    disable() {
        this._clipboard?.unexport();
        this._clipboard = null;
        for (const name of Object.keys(apps))
            Main.wm.removeKeybinding(name);
    }
}
