# X13 work webapps

X13 adds five standalone Chromium menu applications to Osmarg's existing webapps.
Cloud ORGM reuses its existing launcher and profile; the ORGM CLI tools remain
unchanged. The new selections live only in `nixos/hosts/x13/webapps.nix`.

| Menu application | URL | Profile ID |
| --- | --- | --- |
| SLC Daily | https://daily.slci.stream | `slc-daily` |
| SLC Vill Docs | https://vill-docs.slci.stream | `slc-vill-docs` |
| ORGM Administration | https://adm.or-gm.com | `orgm-adm` |
| ORGM Automation | https://automation.or-gm.com | `orgm-automation` |
| ORGM Code | https://code.or-gm.com | `orgm-code` |
| Cloud ORGM | https://cloud.or-gm.com/ | `cloud-orgm` (existing) |

Open these from GNOME's application menu, not a terminal command. Each uses the
existing isolated Chromium engine and its own credential/profile directory under
`~/.local/share/chromium-webapps/<profile-id>`. They do not share the ordinary
Chromium profile or enable browser sync. Existing launcher identities and
security validation are unchanged; other hosts do not select the five new apps.

## Verify before deployment

```bash
python3 tests/x13-webapps.test.py
bash tests/chromium-webapps.bats.sh
```

These evaluate generated menu entries, launchers, selection scope and profile
isolation, including existing Hyprland/i3 behavior and invalid-catalog rejection.
They do not prove installation, endpoint availability or authenticated use.
After the parent builds and activates X13, open all six menu apps in GNOME and
confirm the expected pages and independent sessions. No deployment is performed
by these tests.
