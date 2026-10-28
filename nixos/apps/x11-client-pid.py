"""Resolve an X11 window's host PID through XRes, including Flatpak clients."""
import sys
from Xlib import display
from Xlib.ext import res

window = int(sys.argv[1])
if not 0 < window <= 0xFFFFFFFF:
    raise SystemExit("Invalid X11 window")
connection = display.Display()
try:
    reply = connection.res_query_client_ids([
        {"client": window, "mask": res.LocalClientPIDMask}
    ])
    pids = {
        int(row.value[0]) for row in reply.ids
        if row.spec.mask & res.LocalClientPIDMask and len(row.value) == 1
    }
    if len(pids) != 1 or min(pids) <= 0:
        raise SystemExit("The X server did not identify exactly one local client")
    print(pids.pop())
finally:
    connection.close()
