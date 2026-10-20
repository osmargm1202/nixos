#!/usr/bin/env python3
"""Exercise native resize registrations and shell helper Lua command boundaries."""
import glob
import json
import os
from pathlib import Path
import shutil
import shlex
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT/'dotfiles/config/profiles/hyprland'
USER = ROOT/'dotfiles/config/users/osmarg/profiles/hyprland'
LUA = os.environ.get('ORGM_TEST_LUA') or shutil.which('lua') or glob.glob('/nix/store/*-lua-5.*/bin/lua')[0]

with tempfile.TemporaryDirectory(prefix='hypr-native-') as tmp:
    home = Path(tmp)
    recorder = home/'bindings.lua'
    recorder.write_text(r'''
local root = arg[1]
local function dispatcher(path)
  return setmetatable({}, {
    __index = function(_, key) return dispatcher(path .. "." .. key) end,
    __call = function(_, args) return {path=path, args=args} end,
  })
end
for _, profile in ipairs({"profiles/hyprland", "users/osmarg/profiles/hyprland"}) do
  local bindings = {}
  hl = {dsp=dispatcher("hl.dsp"), bind=function(key, command) bindings[key]=command end}
  dofile(root .. "/dotfiles/config/" .. profile .. "/.config/hypr/lua/keybindings.lua").setup({terminal="kitty", fileManager="nautilus"})
  assert(bindings["SUPER + R"].path == "hl.dsp.layout" and bindings["SUPER + R"].args == "colresize +conf",
    profile .. ": Win+R must cycle configured scrolling widths")
  local expected = {
    ["SUPER + CTRL + minus"]={-20,0}, ["SUPER + CTRL + equal"]={20,0},
    ["SUPER + SHIFT + minus"]={0,-20}, ["SUPER + SHIFT + equal"]={0,20},
    ["SUPER + ALT + left"]={-40,0}, ["SUPER + ALT + right"]={40,0},
    ["SUPER + ALT + up"]={0,-40}, ["SUPER + ALT + down"]={0,40},
  }
  for key, delta in pairs(expected) do
    local command = bindings[key]
    assert(command.path == "hl.dsp.window.resize", profile .. ": " .. key .. " must resize natively")
    assert(command.args.x == delta[1] and command.args.y == delta[2] and command.args.relative == true)
  end
end
''')
    subprocess.run([LUA, str(recorder), str(ROOT)], check=True)

    bin_dir = home/'bin'
    bin_dir.mkdir()
    log = home/'commands.jsonl'
    mock = bin_dir/'hyprctl'
    mock.write_text('''#!/usr/bin/env python3
import json, os, sys
if 'clients' in sys.argv:
    print(json.dumps([dict(address=os.environ.get('TEST_ADDRESS', '0xabc'), **{'class':'windows-rdp' if os.environ.get('TEST_RDP') else 'obsidian'}, title='Notes', workspace={'name':'2'})]))
else:
    with open(os.environ['COMMAND_LOG'], 'a') as out: out.write(json.dumps(sys.argv[1:])+'\\n')
''')
    mock.chmod(0o755)
    env = dict(os.environ, PATH=str(bin_dir)+':'+os.environ['PATH'], HOME=tmp, COMMAND_LOG=str(log))
    subprocess.run([str(USER/'.local/bin/hypr-obsidian-open-or-focus')], env=env, check=True)
    assert json.loads(log.read_text().splitlines()[-1]) == ['dispatch', 'hl.dsp.focus({ window = "address:0xabc" })']
    log.unlink()
    invalid = subprocess.run([str(USER/'.local/bin/hypr-obsidian-open-or-focus')],
                             env=dict(env, TEST_ADDRESS='0xabc" }); os.execute("bad") --'))
    assert invalid.returncode != 0 and not log.exists(), 'Reject malformed client addresses before Lua interpolation'

    lib = home/'rofi-lib'
    lib.write_text("HYPR_ROFI_WIDTH=600\nhypr_rofi_dmenu() { cat >/dev/null; printf '%s\\n' '[2] obsidian — Notes'; }\n")
    subprocess.run([str(BASE/'.local/bin/hypr-rofi-window')], env=dict(env, HYPR_ROFI_LIB=str(lib)), check=True)
    assert json.loads(log.read_text().splitlines()[-1]) == ['dispatch', 'hl.dsp.focus({ window = "address:0xabc" })']
    log.unlink()
    invalid = subprocess.run([str(BASE/'.local/bin/hypr-rofi-window')],
                             env=dict(env, HYPR_ROFI_LIB=str(lib), TEST_ADDRESS='not-an-address'))
    assert invalid.returncode != 0 and not log.exists()

    subprocess.run([str(BASE/'.local/bin/hypr-workspace-button'), 'click', '7'], env=env, check=True)
    assert json.loads(log.read_text().splitlines()[-1]) == ['dispatch', 'hl.dsp.focus({ workspace = 7 })']

    idle = (BASE/'.config/hypr/hypridle.conf').read_text()
    wake = next(line.split('=', 1)[1].strip() for line in idle.splitlines() if 'after_sleep_cmd =' in line)
    wake_args = shlex.split(wake)
    assert wake_args[:2] == ['hyprctl', 'dispatch'] and len(wake_args) == 3
    verify = home/'wake.lua'
    verify.write_text('local called=false; hl={dsp={dpms=function(args) called=true; assert(args.action=="on"); return true end}}\nlocal result='+wake_args[2]+'\nassert(called)')
    subprocess.run([LUA, str(verify)], check=True)

    # Execute the real extracted async RDP placement function without VM startup.
    for user in ('osmarg', 'jarq'):
        source = (ROOT/f'dotfiles/config/users/{user}/programs/containers/.local/bin/windows-rdp').read_text()
        function = source.split('move_next_rdp_window_to_workspace() {', 1)[1].split('\n}\n', 1)[0]
        script = 'move_next_rdp_window_to_workspace() {'+function+'\n}\nmove_next_rdp_window_to_workspace "$TEST_WORKSPACE"\nwait\n'
        for workspace in ('2', 'name:Trabajo "réunion"\\line\x01'):
            log.unlink(missing_ok=True)
            context = dict(env, TEST_WORKSPACE=workspace, TEST_RDP='1')
            subprocess.run(['bash', '-euc', script], env=context, check=True)
            commands = [json.loads(line) for line in log.read_text().splitlines()]
            assert len(commands) == 1 and len(commands[0]) == 2 and commands[0][0] == 'dispatch', commands
            expression = commands[0][1]
            # Evaluate captured payload; byte-escaped workspace must round trip.
            verify = home/'verify.lua'
            verify.write_text('local called=false; hl={dsp={window={move=function(args) called=true; assert(args.workspace==os.getenv("TEST_WORKSPACE") and args.follow==false and args.window=="address:0xabc"); return true end}}}\nlocal result='+expression+'\nassert(called)')
            subprocess.run([LUA, str(verify)], env=context, check=True)

print('PASS: native resize, validated focus helpers, workspace click and RDP placement')
