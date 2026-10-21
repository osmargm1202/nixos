#!/usr/bin/env python3
"""Wrap pinned auth themes without modifying original authentication handlers."""
from pathlib import Path
import sys
import re
def bridge_submit(text):
    # Tokenize the pinned QML, ignoring braces and identifiers inside comments/
    # strings. Only bridge direct Keys handlers on actual editable Qt types.
    pattern=r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|//[^\n]*|/\*[\s\S]*?\*/|[A-Za-z_$][\w$]*|=>|[^\s]'
    tokens=[m for m in re.finditer(pattern,text) if not m[0].startswith(('//','/*'))]
    additions=[]
    for i,token in enumerate(tokens[:-1]):
        if token[0] not in ('TextInput','TextField') or tokens[i+1][0]!='{': continue
        depth=1;j=i+2;accepted=False;handler=None
        while j<len(tokens) and depth:
            value=tokens[j][0]
            if depth==1:
                if value=='onAccepted' and tokens[j+1][0]==':': accepted=True
                if [t[0] for t in tokens[j:j+4]]==['Keys','.','onReturnPressed',':']:
                    start=j+4;k=start;balance=0
                    while k<len(tokens):
                        v=tokens[k][0]
                        if k>start and balance==0 and ('\n' in text[tokens[k-1].end():tokens[k].start()] or v in (';','}')): break
                        if v in ('{','(','['): balance+=1
                        elif v in ('}',')',']'): balance-=1
                        k+=1
                        if balance==0 and v=='}': break
                    handler=text[tokens[start].start():tokens[k-1].end()].strip()
            if value=='{':depth+=1
            elif value=='}':depth-=1
            j+=1
        if handler and not accepted:
            arrow=re.fullmatch(r'\(\s*(\w+)\s*\)\s*=>\s*\{([\s\S]*)\}',handler)
            if arrow:
                handler='{ var '+arrow[1]+'={accepted:false}; '+arrow[2]+' }'
            additions.append((tokens[j-1].start(),'\n// Local touch Enter follows the existing guarded physical Return handler.\nonAccepted: '+handler+'\n'))
    for offset,extra in reversed(additions):text=text[:offset]+extra+text[offset:]
    return text


source,destination,keyboard=map(Path,sys.argv[1:])
for entry in sorted(source.rglob('*')):
    target=destination/entry.relative_to(source)
    if entry.is_dir(): target.mkdir(parents=True,exist_ok=True)
    elif entry.is_file():
        target.parent.mkdir(parents=True,exist_ok=True)
        target.symlink_to(entry.resolve())
for original in sorted(source.rglob('Main.qml')):
    theme=destination/original.parent.relative_to(source)
    (theme/'Main.qml').rename(theme/'OriginalMain.qml')
    original_text=original.read_text()
    bridged=bridge_submit(original_text)
    if bridged!=original_text:
        (theme/'OriginalMain.qml').unlink()
        (theme/'OriginalMain.qml').write_text(bridged)
    (theme/'orgmKeyboard').symlink_to(keyboard)
    (theme/'Main.qml').write_text('''// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import "orgmKeyboard"
Item {
    Loader {
        anchors.fill: parent
        anchors.bottomMargin: localKeyboard.reservedHeight
        source: "OriginalMain.qml"
        onLoaded: item.forceActiveFocus()
    }
    AuthKeyboard { id: localKeyboard; anchors.fill: parent; z: 10000 }
}
''')
