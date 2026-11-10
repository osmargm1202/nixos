// Exercise the shipped extension, not a second model of its behavior.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../nixos/hosts/x13/focus-shortcuts/extension.js'), 'utf8');
const bindings = new Map();
const focused = [];
let launches = 0;
let windows = [];
let state = 0;
const app = {get_windows: () => windows, get_state: () => state, activate: () => launches++};
const ids = [];
let exported = false;
let opened = 0;
const context = {
    Gio: {DBus: {session: {}}, DBusExportedObject: {wrapJSObject: () => ({export() {exported = true;}, unexport() {exported = false;}})}},
    Extension: class {getSettings() {return {}; }},
    Shell: {AppState: {STARTING: 1}, AppSystem: {get_default: () => ({lookup_app: id => {ids.push(id); return app;}})}, ActionMode: {NORMAL: 1}},
    Meta: {KeyBindingFlags: {NONE: 0}},
    Main: {sessionMode: {isLocked: false, isGreeter: false}, panel: {statusArea: {}}, activateWindow: w => focused.push(w), wm: {
        addKeybinding: (name, settings, flags, mode, callback) => bindings.set(name, callback),
        removeKeybinding: name => bindings.delete(name),
    }},
};
vm.createContext(context);
vm.runInContext(source.replace(/^import .*;\n/gm, '').replace('export default class', 'globalThis.Shortcuts = class'), context);
const extension = new context.Shortcuts();
extension.enable();
assert.deepEqual([...bindings.keys()].sort(), ['console', 'files', 'firefox']);
for (const [name, id] of [['console', 'org.gnome.Console.desktop'], ['firefox', 'brave-origin.desktop'], ['files', 'org.gnome.Nautilus.desktop']]) {
    windows = []; state = 0; launches = 0; focused.length = 0;
    bindings.get(name)();
    assert.equal(ids.at(-1), id);
    assert.equal(launches, 1);
    assert.equal(focused.length, 0);
    state = 1;
    bindings.get(name)();
    assert.equal(launches, 1, 'STARTING must not launch a duplicate');
    const old = {get_user_time: () => 10};
    const recent = {get_user_time: () => 20, minimized: true, workspace: 'other'};
    windows = [old, recent];
    bindings.get(name)();
    assert.equal(focused.at(-1), recent, 'focus most recent, even minimized/on another workspace');
    assert.equal(launches, 1, 'existing window must not create a tab/window');
    state = 0; windows = [old];
    bindings.get(name)();
    assert.equal(focused.at(-1), old, 'ordinary existing window remains focusable');
    assert.equal(launches, 1);
}
assert.equal(exported, true);
assert.equal(extension.ShowClipboard(), false, 'absent clipboard extension fails safely');
context.Main.panel.statusArea.clipboardIndicator = {menu: {open() {opened++;}}};
assert.equal(extension.ShowClipboard(), true);
assert.equal(opened, 1);
context.Main.sessionMode.isLocked = true;
assert.equal(extension.ShowClipboard(), false, 'never show clipboard on lock screen');
assert.equal(opened, 1);
extension.disable();
assert.equal(exported, false, 'disable unexports the clipboard interface');
assert.equal(bindings.size, 0, 'disable unregisters every binding');
console.log('PASS: shipped X13 extension focus/open, STARTING guard and disable lifecycle');
