#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
# Only external disk commands are doubled. Run the real guard/argument parser;
# unexpected disk arguments fail even in the successful simulation.
python3 - <<'PY'
import os, pathlib, subprocess, tempfile

script = pathlib.Path('nixos/hosts/envy/prepare-disk.sh').resolve()
with tempfile.TemporaryDirectory() as td:
    d = pathlib.Path(td)
    executable = d / 'boundary'
    executable.write_text('''#!/usr/bin/env python3
import os,sys,pathlib
n=pathlib.Path(sys.argv[0]).name
a=sys.argv[1:]
disk='/dev/nvme0n1'
if n=='readlink': print(disk)
elif n=='id': print('0')
elif n=='blockdev': print('512110190592')
elif n=='lsblk':
 if 'TYPE' in a: print('disk')
 elif 'SERIAL' in a: print(os.environ.get('TEST_SERIAL','PHTE9395032P512B-1'))
 elif 'MOUNTPOINTS' in a: print(os.environ.get('TEST_MOUNT',''))
 else: sys.exit(8)
elif n in ('wipefs','parted','mkfs.fat','mkfs.btrfs','btrfs','mount','umount','chattr','mkdir','udevadm'):
 if n in ('wipefs','parted') and disk not in a: sys.exit(9)
 if n.startswith('mkfs.') and not any(v in (disk+'p1',disk+'p2') for v in a): sys.exit(10)
 with open(os.environ['TEST_WRITES'],'a') as f: f.write(n+' '+' '.join(a)+'\\n')
else: sys.exit(11)
''')
    executable.chmod(0o755)
    names = ['readlink','id','blockdev','lsblk','wipefs','parted','mkfs.fat',
             'mkfs.btrfs','btrfs','mount','umount','chattr','mkdir','udevadm']
    for n in names:
        (d/n).symlink_to(executable)
    log = d/'writes'
    def run(args, *, serial='PHTE9395032P512B-1', mounted='', success=False):
        log.write_text('')
        e = os.environ | {'PATH':str(d)+':'+os.environ['PATH'], 'TEST_WRITES':str(log),
                          'TEST_SERIAL':serial, 'TEST_MOUNT':mounted}
        p = subprocess.run(['bash',str(script),*args],env=e,text=True,capture_output=True)
        assert (p.returncode == 0) == success, (args,p.returncode,p.stdout,p.stderr)
        writes=log.read_text()
        if not success or '--format' not in args:
            assert not writes, (args,writes)
        return writes
    run([], success=True)
    run(['--check'], success=True)
    run(['--format'])
    run(['--format','--confirm','PHTE9395032P512B-2'])
    run(['--format','--confirm','PHTE9395032P512B-1'],serial='PHTE9395032P512B-2')
    run(['--format','--confirm','PHTE9395032P512B-1'],mounted='/mnt/home')
    run(['--format','--confirm','PHTE9395032P512B-1','/dev/nvme1n1'])
    run(['--check','--confirm','PHTE9395032P512B-1','--format'],mounted='/')
    w=run(['--format','--confirm','PHTE9395032P512B-1'],success=True)
    assert 'mkfs.fat ' in w and 'mkfs.btrfs ' in w, w
    assert 'ENVY_EFI' in w and 'ENVY_ROOT' in w, w
    for s in ('@root','@home','@nix','@log','@windows'):
        assert 'btrfs subvolume create /mnt/'+s+'\n' in w, w
    assert 'chattr +C /mnt/@windows\n' in w, w
    assert '/dev/nvme1n1' not in w and '/dev/sda' not in w, w
print('PASS: envy disk guards and authorized formatting behavior')
PY
