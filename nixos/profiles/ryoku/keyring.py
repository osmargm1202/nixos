"""Select a dedicated blank collection while retaining all existing keyrings."""
import time

import dbus

SERVICE = "org.freedesktop.Secret.Service"
COLLECTION = "org.freedesktop.Secret.Collection"
INTERNAL = "org.gnome.keyring.InternalUnsupportedGuiltRiddenInterface"
NAME = "orgm-never-ask"


def select_blank_collection():
    bus = dbus.SessionBus()
    root = bus.get_object("org.freedesktop.secrets", "/org/freedesktop/secrets")
    service = dbus.Interface(root, SERVICE)
    props = dbus.Interface(root, "org.freedesktop.DBus.Properties")
    collection = None
    for path in props.Get(SERVICE, "Collections"):
        obj = bus.get_object("org.freedesktop.secrets", path)
        attributes = dbus.Interface(obj, "org.freedesktop.DBus.Properties")
        if str(attributes.Get(COLLECTION, "Label")) == NAME:
            if bool(attributes.Get(COLLECTION, "Locked")):
                raise RuntimeError("orgm-never-ask is locked; keeping its contents intact")
            collection = path
            break
    if collection is None:
        _, session = service.OpenSession("plain", dbus.String("", variant_level=1))
        secret = dbus.Struct(
            (session, dbus.ByteArray(b""), dbus.ByteArray(b""), dbus.String("text/plain")),
            signature="oayays",
        )
        attributes = dbus.Dictionary(
            {COLLECTION + ".Label": dbus.String(NAME, variant_level=1)}, signature="sv"
        )
        internal = dbus.Interface(root, INTERNAL)
        collection = internal.CreateWithMasterPassword(attributes, secret)
        dbus.Interface(bus.get_object("org.freedesktop.secrets", session),
                       "org.freedesktop.Secret.Session").Close()
    service.SetAlias("default", collection)


if __name__ == "__main__":
    for attempt in range(15):
        try:
            select_blank_collection()
            break
        except dbus.DBusException:
            if attempt == 14:
                raise
            time.sleep(1)
