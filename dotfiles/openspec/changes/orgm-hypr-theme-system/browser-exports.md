# Browser theme exports

Generated browser targets are export-only by default. They do not edit Chromium, Zen Browser, Firefox, or profile files.

## Chromium

`orgm-hypr theme apply` plans a generated Chromium extension directory under:

```text
$XDG_STATE_HOME/orgm-hypr/theme/exports/chromium/<theme>-<mode>/
```

Contents:

- `manifest.json` with Chromium theme color RGB arrays.
- `wallpaper.<ext>` only when the theme registry includes a readable wallpaper path.

Manual load:

1. Open `chrome://extensions` or `chromium://extensions`.
2. Enable Developer mode.
3. Choose **Load unpacked**.
4. Select the generated export directory.
5. Restart Chromium if colors do not refresh.

Profile safety: no Chromium profile is mutated. Remove the loaded unpacked extension to undo.

## Zen Browser

`orgm-hypr theme apply` plans a generated Zen export directory under:

```text
$XDG_STATE_HOME/orgm-hypr/theme/exports/zen/<theme>-<mode>/
```

Contents:

- `README.md` with per-export instructions.
- `userChrome.css` best-effort CSS variables and browser chrome styling.

Manual load:

1. Open `about:profiles` in Zen Browser.
2. Identify the profile you want to theme.
3. Back up `<profile>/chrome/userChrome.css` if it exists.
4. Copy generated `userChrome.css` into `<profile>/chrome/userChrome.css` only after reviewing it.
5. Restart Zen Browser.

Profile safety: no Zen profile is mutated by default. Automatic profile mutation remains out of scope until explicit configuration, backup, and rollback support exist.
