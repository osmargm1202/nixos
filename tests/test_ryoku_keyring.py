import importlib.util
import sys
import types
import unittest
from pathlib import Path


class SecretService:
    def __init__(self, collections):
        self.collections = collections.copy()
        self.created = []
        self.alias = None
        self.closed = False

    def Get(self, interface, property):
        return list(self.collections)

    def OpenSession(self, algorithm, value):
        return "", "/session"

    def CreateWithMasterPassword(self, attributes, secret):
        self.created.append((attributes, secret))
        return "/new"

    def SetAlias(self, alias, path):
        self.alias = (alias, path)

    def Close(self):
        self.closed = True


class KeyringTests(unittest.TestCase):
    def run_helper(self, collections):
        service = SecretService(collections)
        bus = types.SimpleNamespace(get_object=lambda name, path: path)

        def interface(path, name):
            if path in collections:
                return types.SimpleNamespace(Get=lambda iface, prop: collections[path][prop])
            return service

        mock_dbus = types.SimpleNamespace(
            SessionBus=lambda: bus, Interface=interface,
            String=lambda value, **kwargs: value, ByteArray=bytes,
            Struct=lambda value, **kwargs: tuple(value),
            Dictionary=lambda value, **kwargs: value,
        )
        original = sys.modules.get("dbus")
        sys.modules["dbus"] = mock_dbus
        try:
            path = Path(__file__).parents[1] / "nixos/profiles/ryoku/keyring.py"
            spec = importlib.util.spec_from_file_location("keyring_under_test", path)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            module.select_blank_collection()
        finally:
            if original is None:
                sys.modules.pop("dbus", None)
            else:
                sys.modules["dbus"] = original
        return service

    def test_existing_encrypted_keyrings_are_preserved(self):
        existing = {"/old": {"Label": "login", "Locked": True}}
        service = self.run_helper(existing)
        self.assertEqual(service.collections, existing)
        self.assertEqual(service.alias, ("default", "/new"))
        self.assertEqual(len(service.created), 1)
        self.assertEqual(service.created[0][1][2], b"")
        self.assertTrue(service.closed)

    def test_reuses_passwordless_collection(self):
        service = self.run_helper({"/blank": {"Label": "orgm-never-ask", "Locked": False}})
        self.assertEqual(service.alias, ("default", "/blank"))
        self.assertEqual(service.created, [])

    def test_does_not_reset_a_locked_collection(self):
        with self.assertRaisesRegex(RuntimeError, "keeping its contents intact"):
            self.run_helper({"/locked": {"Label": "orgm-never-ask", "Locked": True}})


if __name__ == "__main__":
    unittest.main()
