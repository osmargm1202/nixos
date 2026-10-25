#!/usr/bin/env python3
"""Apply ordered XDG defaults only; never execute applications or replace other preferences."""
import argparse
import configparser
import fcntl
import json
import os
from pathlib import Path
import stat
import tempfile


def apply(path, policy, dry_run=False):
    path = Path(path)
    for mime, handlers in policy.items():
        if not isinstance(mime,str) or '/' not in mime or any(c in mime for c in '\n\r;='):
            raise ValueError('Invalid MIME type')
        if not isinstance(handlers,list) or not handlers or any(
            not isinstance(h,str) or not h.endswith('.desktop') or any(c in h for c in '/;\n\r\0') for h in handlers):
            raise ValueError('Invalid desktop handler list')
    path.parent.mkdir(parents=True, exist_ok=True)
    lock_flags = os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW
    with os.fdopen(os.open(path.parent/'.orgm-artcraft-mime.lock',lock_flags,0o600),'w') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        if path.is_symlink():
            raise ValueError('Refusing symlinked mimeapps.list')
        original = None
        try:
            fd = os.open(path,os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        except FileNotFoundError:
            pass
        else:
            with os.fdopen(fd,'rb') as source:
                info=os.fstat(source.fileno())
                if not stat.S_ISREG(info.st_mode) or info.st_size>1024*1024:
                    raise ValueError('Invalid mimeapps.list file')
                original=source.read().decode('utf-8')
        config=configparser.ConfigParser(interpolation=None,strict=False)
        config.optionxform=str
        if original is not None:config.read_string(original)
        section='Default Applications'
        if not config.has_section(section):config.add_section(section)
        changes=[]
        for mime,handlers in policy.items():
            value=';'.join(dict.fromkeys(handlers))+';'
            if config.get(section,mime,fallback='')!=value:
                config.set(section,mime,value);changes.append(mime)
        if not changes or dry_run:return changes
        if original is not None:
            fd,backup=tempfile.mkstemp(prefix='mimeapps-artcraft-backup-',dir=path.parent)
            with os.fdopen(fd,'w') as output:output.write(original)
        fd,temporary=tempfile.mkstemp(prefix='.mimeapps-artcraft-',dir=path.parent)
        try:
            with os.fdopen(fd,'w') as output:config.write(output,space_around_delimiters=False)
            os.replace(temporary,path)
        finally:Path(temporary).unlink(missing_ok=True)
        return changes


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--policy',required=True,type=Path)
    parser.add_argument('--dry-run',action='store_true')
    args=parser.parse_args()
    policy=json.loads(args.policy.read_text())
    path=Path(os.environ.get('XDG_CONFIG_HOME',Path.home()/'.config'))/'mimeapps.list'
    print(json.dumps({'changed':apply(path,policy,args.dry_run),'file':str(path),'dry_run':args.dry_run}))

if __name__=='__main__':main()
