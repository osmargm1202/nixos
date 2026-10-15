#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
# Only external disk commands are doubled. Run the real guard/argument parser;
# unexpected disk arguments fail even in the successful simulation.
python3 - <<'PY'
import os, pathlib, shutil, subprocess, sys, tempfile

script = pathlib.Path('nixos/hosts/envy/prepare-disk.sh').resolve()
with tempfile.TemporaryDirectory() as td:
    d = pathlib.Path(td)
    executable = d / 'boundary'
    executable.write_text(f'#!{sys.executable}\n' + '''
import os,sys,pathlib
n=pathlib.Path(sys.argv[0]).name
a=sys.argv[1:]
disk='/dev/nvme0n1'
inventory = {
 'readlink': (['-e', '/dev/disk/by-id/nvme-INTEL_HBRPEKNX0202AH_PHTE9395032P512B-1'], 'TEST_MAPPING', disk),
 'id': (['-u'], 'TEST_UID', '0'),
 'blockdev': (['--getsize64', disk], 'TEST_SIZE', '512110190592'),
 'lsblk:TYPE': (['-dnro', 'TYPE', disk], 'TEST_TYPE', 'disk'),
 'lsblk:SERIAL': (['-dnro', 'SERIAL', disk], 'TEST_SERIAL', 'PHTE9395032P512B-1'),
 'lsblk:MOUNTPOINTS': (['-nr', '-o', 'MOUNTPOINTS', disk], 'TEST_MOUNT', ''),
}
key = 'lsblk:'+('MOUNTPOINTS' if 'MOUNTPOINTS' in a else a[1]) if n=='lsblk' else n
if key in inventory:
 expected, variable, default = inventory[key]
 if a != expected: sys.exit(8)
 failed = os.environ.get('TEST_FAIL') == key
 if not failed or os.environ.get('TEST_FAIL_OUTPUT') == 'valid':
  print(os.environ.get(variable, default))
 if failed: sys.exit(7)
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
    failures = []
    bash = shutil.which('bash')
    def run(args, *, case='', success=False, missing=None, **inventory):
        log.write_text('')
        # Hermetic PATH: even a missing boundary command can never fall back to
        # the real host inventory or formatter. The double has an absolute shebang.
        e = os.environ | {'PATH':str(d), 'TEST_WRITES':str(log)}
        e = {k:v for k,v in e.items() if not k.startswith('TEST_') or k == 'TEST_WRITES'}
        e.update({'TEST_'+k.upper():v for k,v in inventory.items()})
        if missing:
            (d/missing).unlink()
        try:
            p = subprocess.run([bash,str(script),*args],env=e,text=True,capture_output=True)
        finally:
            if missing:
                (d/missing).symlink_to(executable)
        writes=log.read_text()
        errors = []
        if not success or '--format' not in args:
            if writes:
                errors.append('unexpected writes: '+writes)
        if (p.returncode == 0) != success:
            errors.append(f'exit={p.returncode}, stdout={p.stdout!r}, stderr={p.stderr!r}')
        if errors:
            failures.append((case or args, errors))
        return writes

    authorized = ['--format','--confirm','PHTE9395032P512B-1']
    run([], success=True)
    run(['--check'], success=True)
    run(['--format'])
    run(['--format','--confirm','PHTE9395032P512B-2'])
    run(['--format','--confirm'])
    run(authorized, serial='PHTE9395032P512B-2')
    run(authorized, mount='/mnt/home')
    run(authorized+['/dev/nvme1n1'])
    run(['--check',*authorized], mount='/')
    # Each altered identity/privilege must fail before the first write.
    for mapping in ('/dev/nvme1n1','/dev/sda','/dev/nvme0n1p2',''):
        run(authorized, case='changed mapping '+repr(mapping), mapping=mapping)
    for kind in ('part','lvm',''):
        run(authorized, case='non-disk type '+repr(kind), type=kind)
    for size in ('512110190591','512110190593','0',''):
        run(authorized, case='wrong size '+repr(size), size=size)
    for uid in ('1000',''):
        run(authorized, case='non-root UID '+repr(uid), uid=uid)
    for mount in ('/mnt/home','/',' \n/mnt/boot\n'):
        run(authorized, case='mounted descendant '+repr(mount), mount=mount)
    for command in ('readlink','lsblk','blockdev','id'):
        run(authorized, case='missing '+command, missing=command)
    # Correct-looking stdout must never conceal a failed inventory command.
    # Removing explicit status handling would make these cases write again.
    for command in ('readlink','lsblk:TYPE','lsblk:SERIAL','lsblk:MOUNTPOINTS','blockdev','id'):
        for output in ('empty','valid'):
            run(authorized, case=f'failed {command} ({output} stdout)',
                fail=command, fail_output=output)
    w=run(['--format','--confirm','PHTE9395032P512B-1'],success=True)
    assert 'mkfs.fat ' in w and 'mkfs.btrfs ' in w, w
    assert 'ENVY_EFI' in w and 'ENVY_ROOT' in w, w
    for s in ('@root','@home','@nix','@log','@windows'):
        assert 'btrfs subvolume create /mnt/'+s+'\n' in w, w
    assert 'chattr +C /mnt/@windows\n' in w, w
    assert '/dev/nvme1n1' not in w and '/dev/sda' not in w, w
    assert not failures, '\n'.join(f'{case}: {errors}' for case, errors in failures)
print('PASS: envy disk guards and authorized formatting behavior')
PY
