#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
# Keep real temporary directories/permissions. Only Btrfs, mount inventory and
# privilege/ownership boundaries are doubled: no real disks or mounts are used.
python3 - <<'PY'
import os, pathlib, shutil, stat, subprocess, sys, tempfile

script = pathlib.Path('nixos/hosts/envy/prepare-snapshots.sh').resolve()
bash = shutil.which('bash')
with tempfile.TemporaryDirectory() as td:
    d = pathlib.Path(td)
    boundary = d / 'boundary'
    boundary.write_text(f'#!{sys.executable}\n' + '''
import os,pathlib,sys
n=pathlib.Path(sys.argv[0]).name
a=sys.argv[1:]
roots=[os.environ['FIXTURE_ROOT'],os.environ['FIXTURE_HOME']]
key=n
if n=='id':
 if a!=['-u']: sys.exit(90)
 out=os.environ.get('TEST_UID','0')
elif n=='findmnt':
 if len(a)!=5 or a[:3]!=['--noheadings','--output','FSTYPE'] or a[3]!='--mountpoint' or a[4] not in roots: sys.exit(91)
 key='findmnt:'+('root' if a[4]==roots[0] else 'home')
 out=os.environ.get('TEST_'+key.split(':')[1].upper()+'_TYPE','btrfs')
elif n=='btrfs':
 if len(a)!=4 or a[0]!='subvolume' or a[2]!='--' or a[3] not in [r+'/.snapshots' for r in roots]: sys.exit(92)
 path=pathlib.Path(a[3])
 key='btrfs:'+a[1]
 if a[1]=='show':
  out='Name: .snapshots'
  if not (path/'.fixture-subvolume').is_file(): sys.exit(1)
 elif a[1]=='create':
  with open(os.environ['WRITE_LOG'],'a') as f: f.write('create '+str(path)+'\\n')
  if os.environ.get('TEST_FAIL')==key: sys.exit(7)
  path.mkdir()
  (path/'.fixture-subvolume').touch()
  sys.exit(0)
 else: sys.exit(93)
elif n=='chown':
 if len(a)!=3 or a[:2]!=['root:root','--'] or a[2] not in [r+'/.snapshots' for r in roots]: sys.exit(94)
 with open(os.environ['WRITE_LOG'],'a') as f: f.write('chown '+a[2]+'\\n')
 sys.exit(7 if os.environ.get('TEST_FAIL')=='chown' else 0)
else: sys.exit(95)
if os.environ.get('TEST_FAIL')==key:
 if os.environ.get('TEST_FAIL_OUTPUT')=='valid': print(out)
 sys.exit(7)
print(out)
''')
    boundary.chmod(0o755)
    bin = d/'bin'
    bin.mkdir()
    for name in ('id', 'findmnt', 'btrfs', 'chown'):
        (bin/name).symlink_to(boundary)
    # chmod has real effects, but cannot escape the fixture paths.
    (bin/'chmod').symlink_to(shutil.which('chmod'))
    count = 0
    def run(*, success=False, args=None, existing=None, missing=None, write_failure=False, **settings):
        global count
        count += 1
        case = d/str(count)
        case.mkdir()
        root, home = case/'root with spaces', case/'home'
        root.mkdir(); home.mkdir()
        roots = (root, home)
        for target, kind in (existing or {}).items():
            p = roots[target]/'.snapshots'
            if kind == 'symlink':
                p.symlink_to(case/'outside')
            elif kind == 'symlink-dir':
                outside = case/'outside'
                outside.mkdir(mode=0o755)
                p.symlink_to(outside)
            elif kind == 'file':
                p.write_text('preserve this data')
            else:
                p.mkdir(mode=0o755)
                (p/'keep').write_text('preserve this data')
                if kind == 'subvolume': (p/'.fixture-subvolume').touch()
        log = case/'writes'
        log.touch()
        before = {p: p.stat().st_mode for p in case.rglob('*') if p.is_dir() and not p.is_symlink()}
        env = {k:v for k,v in os.environ.items() if not k.startswith('TEST_')}
        env.update(PATH=str(bin), FIXTURE_ROOT=str(root), FIXTURE_HOME=str(home), WRITE_LOG=str(log))
        env.update({'TEST_'+k.upper():str(v) for k,v in settings.items()})
        if missing: (bin/missing).unlink()
        actual_args = [str(root), str(root)] if args == 'duplicate' else (args if args is not None else map(str, roots))
        try:
            p = subprocess.run([bash, str(script), *actual_args], env=env, text=True, capture_output=True)
        finally:
            if missing: (bin/missing).symlink_to(shutil.which('chmod') if missing == 'chmod' else boundary)
        assert (p.returncode == 0) == success, (count, settings, existing, args, p.returncode, p.stdout, p.stderr)
        if write_failure:
            # A write failure is surfaced and subsequent paths are untouched;
            # existing data is not deleted in an attempted rollback.
            assert not (home/'.snapshots').exists()
            assert log.read_text().count('create ') == 1
        elif not success:
            assert log.read_text() == '', (count, log.read_text())
            for path, mode in before.items(): assert path.stat().st_mode == mode, (count, path)
            for i, r in enumerate(roots):
                snapshot = r/'.snapshots'
                if i not in (existing or {}): assert not snapshot.exists() and not snapshot.is_symlink()
                elif existing[i] == 'file': assert snapshot.read_text() == 'preserve this data'
                elif existing[i].startswith('symlink'): assert snapshot.is_symlink()
        else:
            for r in roots:
                assert (r/'.snapshots'/'.fixture-subvolume').is_file()
                assert stat.S_IMODE((r/'.snapshots').stat().st_mode) == 0o700
            for target, kind in (existing or {}).items():
                if kind == 'subvolume': assert (roots[target]/'.snapshots'/'keep').read_text() == 'preserve this data'
            assert log.read_text().count('create ') == 2 - len(existing or {})
            assert log.read_text().count('chown ') == 2
        for file in case.rglob('keep'): assert file.read_text() == 'preserve this data'
        if (case/'outside').is_dir(): assert stat.S_IMODE((case/'outside').stat().st_mode) == 0o755

    # Missing production create/chmod, wrong paths, or non-idempotent create
    # fails these independently hand-derived filesystem assertions.
    run(success=True)
    run(success=True, existing={0:'subvolume', 1:'subvolume'})
    run(success=True, existing={1:'subvolume'})
    for args in ([], ['/'], ['/', '/home', '/nix'], ['', '/home'], ['relative', '/home'], 'duplicate'):
        run(args=args)
    for uid in ('1000', ''): run(uid=uid)
    for mount in ('root', 'home'):
        for kind in ('ext4', '', 'btrfs\next4'):
            run(**{mount+'_type':kind})
        for output in ('empty', 'valid'):
            run(fail='findmnt:'+mount, fail_output=output)
    for output in ('empty', 'valid'):
        run(fail='id', fail_output=output)
        run(existing={0:'subvolume', 1:'subvolume'}, fail='btrfs:show', fail_output=output)
    for target in (0, 1):
        for kind in ('file', 'directory', 'symlink', 'symlink-dir'):
            run(existing={target:kind})
    for command in ('id', 'findmnt', 'btrfs', 'chown', 'chmod'):
        run(missing=command)
    run(write_failure=True, fail='btrfs:create')
    run(write_failure=True, fail='chown')
print(f'PASS: {count} offline recovery cases (no real Btrfs operations)')
PY

# Exercise the integrated host and pinned Snapper module, not source text.
# Do not re-import a mutable module alongside its immutable flake copy.
nix eval --raw --impure --expr '
let
 f = builtins.getFlake ("path:" + toString ./.);
 c = f.nixosConfigurations.envy.config;
 lib = f.inputs.nixpkgs.lib;
 s = c.services.snapper;
 prep = c.systemd.services.envy-prepare-snapshots;
 expected = name: path:
   let p = s.configs.${name}; in
   p.SUBVOLUME == path && p.FSTYPE == "btrfs"
   && p.ALLOW_USERS == [] && p.ALLOW_GROUPS == []
   && p.TIMELINE_CREATE && p.TIMELINE_CLEANUP
   && p.TIMELINE_LIMIT_DAILY == 7
   && builtins.all (k: p.${k} == 0) [
     "TIMELINE_LIMIT_HOURLY" "TIMELINE_LIMIT_WEEKLY" "TIMELINE_LIMIT_MONTHLY"
     "TIMELINE_LIMIT_QUARTERLY" "TIMELINE_LIMIT_YEARLY"
   ]
   && p.NUMBER_CLEANUP && p.NUMBER_LIMIT == 3;
 gated = name: let u = c.systemd.services.${name}; in
   builtins.elem "envy-prepare-snapshots.service" u.requires
   && builtins.elem "envy-prepare-snapshots.service" u.after;
in
assert lib.assertMsg (builtins.attrNames s.configs == [ "home" "root" ] && expected "root" "/" && expected "home" "/home")
 "root/home retention or privilege boundary regressed";
assert lib.assertMsg (!s.snapshotRootOnBoot && s.snapshotInterval == "daily" && s.persistentTimer)
 "daily recovery must not enable boot snapshots or miss powered-off days";
assert lib.assertMsg (c.systemd.timers.snapper-timeline.timerConfig.OnCalendar == "daily"
 && c.systemd.timers.snapper-timeline.timerConfig.Persistent)
 "generated Snapper timeline must use the daily persistent schedule";
assert lib.assertMsg (builtins.all gated [ "snapperd" "snapper-timeline" "snapper-cleanup" ])
 "Snapper must not race preparation";
assert lib.assertMsg (prep.serviceConfig.Type == "oneshot" && prep.serviceConfig.User == "root"
 && prep.serviceConfig.RemainAfterExit && prep.unitConfig.RequiresMountsFor == [ "/" "/home" ]
 && builtins.elem "multi-user.target" prep.wantedBy)
 "snapshot preparation must be privileged and wait for both mounts";
assert lib.assertMsg (builtins.hasAttr "snapper/configs/root" c.environment.etc
 && builtins.hasAttr "snapper/configs/home" c.environment.etc)
 "Snapper must generate both declarative configurations";
"PASS: actual envy/pinned Snapper configs, timer and preparation ordering\n"
'
