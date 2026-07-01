# ColourSelect Theme Chooser — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the "Page under construction" stub in Nexus > Wallpaper & Style > Colours with a working theme chooser: "From Wallpaper" (matugen dynamic) and a predefined Teal theme, with per-mode (dark/light) persistence.

**Architecture:** Teal colour files live in `osmargm1202/shell` fork at `themes/teal/`; the shell's `flake.nix` overrides `caelestia-cli` via `overrideAttrs` to inject those files into the CLI's bundled scheme data; `ThemeEngine.qml` singleton manages per-mode prefs in `GlobalConfig.colours` and applies via `caelestia scheme set`; `ColourSelect.qml` replaces the stub using `PageBase`.

**Tech Stack:** QML (Quickshell), Python (one-time light-scheme generation), Nix (`overrideAttrs`)

---

## Background: Key Discoveries

- `caelestia scheme set -n <name>` only accepts names whose directories exist in `scheme_data_dir` (inside caelestia-cli Nix store path — read-only at runtime).
- The shell's `with-cli` package passes `caelestia-cli` as a `callPackage` argument → we can override it via `overrideAttrs` in the shell fork's `flake.nix`.
- Colour file format: `key value` per line (no `#`), extension `.txt` (e.g. `dark.txt`), path: `data/schemes/<name>/<flavour>/<mode>.txt`.
- `gen_scheme(scheme, Hct)` in `caelestia.utils.material.generator` generates the full colour dict including M3, terminal, and catppuccin-style keys.
- CLI invocations: `caelestia scheme set -n teal -f default -m dark` / `caelestia scheme set -n dynamic`.
- `GlobalConfig` comes from `import Caelestia.Config`; services read it as `GlobalConfig.colours.darkTheme`.
- `Colours` (the active palette singleton) is in `qs.services`; `ThemeEngine.qml` is also placed in `services/` so both are in scope.
- Shell QML components available in the nexus pages: `PageBase` (from `qs.modules.nexus.common`), `StyledText`, `MaterialIcon` (from `qs.components`), `Tokens` (from `qs.modules.nexus.common`).

---

## File Map

### osmargm1202/shell fork (clone to `/tmp/caelestia-shell-dev`)

| Action | Path |
|--------|------|
| NEW | `themes/teal/dark.txt` — teal dark colour file (key value per line) |
| NEW | `themes/teal/light.txt` — teal light colour file |
| MODIFY | `flake.nix` — `overrideAttrs` on caelestia-cli inside `packages` block |
| NEW | `services/ThemeEngine.qml` — `pragma Singleton`, theme prefs + CLI calls |
| REPLACE | `modules/nexus/pages/wallandstyle/ColourSelect.qml` — full two-section UI |
| NEW | `modules/nexus/pages/wallandstyle/ThemeCard.qml` — reusable theme card |

### /home/osmarg/Hobby/nixos (this repo)

| Action | Path |
|--------|------|
| UPDATE | `flake.lock` — `nix flake update caelestia-shell` after push |

---

## Task 0: Clone Shell Fork

- [ ] **Clone**
  ```bash
  git clone https://github.com/osmargm1202/shell /tmp/caelestia-shell-dev
  cd /tmp/caelestia-shell-dev
  git log --oneline -5
  ```
  Expected: clean clone, 5 recent commits visible.

---

## Task 1: Generate Teal Colour Files

**Files:**
- Create: `themes/teal/dark.txt`
- Create: `themes/teal/light.txt`

- [ ] **Create directory**
  ```bash
  mkdir -p /tmp/caelestia-shell-dev/themes/teal
  ```

- [ ] **Write dark.txt** — full M3 + catppuccin colour set for teal dark mode (from current active scheme cache)
  ```bash
  cat > /tmp/caelestia-shell-dev/themes/teal/dark.txt << 'EOF'
  primary_paletteKeyColor 25856e
  secondary_paletteKeyColor 5d7e73
  tertiary_paletteKeyColor fe9f91
  neutral_paletteKeyColor 737875
  neutral_variant_paletteKeyColor 6e7a75
  background 101413
  onBackground dfe3e0
  surface 101413
  surfaceDim 101413
  surfaceBright 353a38
  surfaceContainerLowest 0b0f0d
  surfaceContainerLow 181d1b
  surfaceContainer 1c211f
  surfaceContainerHigh 262b29
  surfaceContainerHighest 313634
  onSurface dfe3e0
  surfaceVariant 3e4945
  onSurfaceVariant bdc9c3
  inverseSurface dfe3e0
  inverseOnSurface 2d312f
  outline 88938e
  outlineVariant 3e4945
  shadow 000000
  scrim 000000
  surfaceTint 7ed7bc
  primary 62bba2
  onPrimary 00261d
  primaryContainer 6fc8ae
  onPrimaryContainer 005342
  inversePrimary 006b57
  secondary abcec1
  onSecondary 16362d
  secondaryContainer 2d4d43
  onSecondaryContainer 9abcb0
  tertiary ffb4a9
  onTertiary 591c15
  tertiaryContainer d0796c
  onTertiaryContainer 000000
  error ffb4ab
  onError 690005
  errorContainer 93000a
  onErrorContainer ffdad6
  primaryFixed 9af4d8
  primaryFixedDim 7ed7bc
  onPrimaryFixed 002019
  onPrimaryFixedVariant 005141
  secondaryFixed c7eadd
  secondaryFixedDim abcec1
  onSecondaryFixed 002019
  onSecondaryFixedVariant 2d4d43
  tertiaryFixed ffdad5
  tertiaryFixedDim ffb4a9
  onTertiaryFixed 3c0704
  onTertiaryFixedVariant 763229
  term0 343434
  term1 769e00
  term2 6fe1a8
  term3 97fbb6
  term4 78b6a7
  term5 7aaee9
  term6 8bd9b9
  term7 cfdccf
  term8 9ca59b
  term9 85b900
  term10 69f6b4
  term11 d2ffdc
  term12 a5c8bb
  term13 cec06b
  term14 95edc7
  term15 ffffff
  rosewater f1f3e5
  flamingo e3e4c5
  pink bae2ff
  mauve 5bd0df
  red c5b542
  maroon c6c177
  peach a9daab
  yellow d8fadf
  green 97f2cd
  teal a3eed8
  sky 96ebd9
  sapphire 73d8ca
  blue 57cec9
  lavender 84dbda
  klink 00978f
  klinkSelection 00978f
  kvisited 008ca9
  kvisitedSelection 008ca9
  knegative 838f00
  knegativeSelection 838f00
  kneutral 34c359
  kneutralSelection 34c359
  kpositive 00c095
  kpositiveSelection 00c094
  text dfe3e0
  subtext1 bdc9c3
  subtext0 88938e
  overlay2 76807c
  overlay1 646c69
  overlay0 535b58
  surface2 434a47
  surface1 333937
  surface0 212625
  base 101413
  mantle 101413
  crust 0f1312
  success B5CCBA
  onSuccess 213528
  successContainer 374B3E
  onSuccessContainer D1E9D6
  EOF
  ```

- [ ] **Generate light.txt** using caelestia's Python material engine (same seed, light mode)
  ```bash
  python3 - << 'PYEOF' > /tmp/caelestia-shell-dev/themes/teal/light.txt
  import sys
  NIX_PKG = '/nix/store/x089s89251m5bakh072cq00gly57pp36-caelestia-cli-b00dabaa9351d1383dfba162f5b3575b49a126e1/lib/python3.13/site-packages'
  sys.path.insert(0, NIX_PKG)
  from caelestia.utils.material.generator import gen_scheme, hex_to_hct

  class _S:
      mode = 'light'
      variant = 'fidelity'
      flavour = 'default'
      name = 'teal'

  colours = gen_scheme(_S(), hex_to_hct('25856e'))
  for k, v in colours.items():
      print(f'{k} {v}')
  PYEOF
  ```

- [ ] **Verify both files**
  ```bash
  wc -l /tmp/caelestia-shell-dev/themes/teal/dark.txt \
         /tmp/caelestia-shell-dev/themes/teal/light.txt
  grep '^primary ' /tmp/caelestia-shell-dev/themes/teal/dark.txt
  grep '^primary ' /tmp/caelestia-shell-dev/themes/teal/light.txt
  ```
  Expected: 80+ lines each; dark `primary 62bba2`; light `primary 006b5...`.

- [ ] **Commit**
  ```bash
  cd /tmp/caelestia-shell-dev
  git add themes/
  git commit -m "feat(themes): add Teal colour scheme dark/light colour files"
  ```

---

## Task 2: Override caelestia-cli in Shell Fork flake.nix

**Files:**
- Modify: `flake.nix`

The goal: make `caelestia scheme set -n teal` valid by injecting `themes/teal/dark.txt` and `light.txt` into the CLI's bundled `data/schemes/teal/default/` directory at build time.

- [ ] **Open** `/tmp/caelestia-shell-dev/flake.nix` and find the `packages = forAllSystems` block. It currently reads:

  ```nix
  packages = forAllSystems (pkgs: rec {
    caelestia-shell = pkgs.callPackage ./nix {
      inherit (inputs) m3shapes;
      rev = self.rev or self.dirtyRev;
      stdenv = pkgs.clangStdenv;
      quickshell = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
        withX11 = false;
        withI3 = false;
      };
      caelestia-cli = inputs.caelestia-cli.packages.${pkgs.stdenv.hostPlatform.system}.default;
    };
    with-cli = caelestia-shell.override {withCli = true;};
    debug = caelestia-shell.override {debug = true;};
    default = caelestia-shell;
  });
  ```

- [ ] **Replace** the block with the override version:

  ```nix
  packages = forAllSystems (pkgs:
    let
      sys = pkgs.stdenv.hostPlatform.system;
      caelestia-cli = (inputs.caelestia-cli.packages.${sys}.default).overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          schemeDir=$(echo "$out"/lib/python*/site-packages/caelestia/data/schemes)
          install -Dm644 ${./themes/teal/dark.txt} "$schemeDir/teal/default/dark.txt"
          install -Dm644 ${./themes/teal/light.txt} "$schemeDir/teal/default/light.txt"
        '';
      });
    in
    rec {
      caelestia-shell = pkgs.callPackage ./nix {
        inherit (inputs) m3shapes;
        rev = self.rev or self.dirtyRev;
        stdenv = pkgs.clangStdenv;
        quickshell = inputs.quickshell.packages.${sys}.default.override {
          withX11 = false;
          withI3 = false;
        };
        inherit caelestia-cli;
      };
      with-cli = caelestia-shell.override {withCli = true;};
      debug = caelestia-shell.override {debug = true;};
      default = caelestia-shell;
    });
  ```

- [ ] **Check Nix syntax**
  ```bash
  cd /tmp/caelestia-shell-dev
  nix flake check --no-build 2>&1 | tail -5
  ```
  Expected: no syntax errors (evaluation-level warnings about impure refs are OK).

- [ ] **Commit**
  ```bash
  git add flake.nix
  git commit -m "feat: override caelestia-cli in flake to inject Teal scheme files"
  ```

---

## Task 3: Create services/ThemeEngine.qml

**Files:**
- Create: `services/ThemeEngine.qml`

`ThemeEngine` is a `pragma Singleton` auto-discovered by Quickshell in `qs.services`. It reads/writes `GlobalConfig.colours.{darkTheme,lightTheme}` and calls `caelestia scheme set` when the active theme changes.

- [ ] **Create the file** at `/tmp/caelestia-shell-dev/services/ThemeEngine.qml`:

  ```qml
  pragma Singleton
  pragma ComponentBehavior: Bound

  import QtQuick
  import Quickshell
  import Caelestia.Config
  import qs.services

  Singleton {
      id: root

      // Per-mode selections ("dynamic" = From Wallpaper, any other = theme id)
      property string darkTheme: "dynamic"
      property string lightTheme: "dynamic"

      // Hard-coded theme list for v1 (one theme: Teal)
      readonly property var themeList: [
          {
              "id": "teal",
              "name": "Teal",
              "preview": {
                  "dark":  { "primary": "62bba2", "secondary": "abcec1",
                             "bg": "101413", "surface": "1c211f" },
                  "light": { "primary": "006b56", "secondary": "45655a",
                             "bg": "f6faf7", "surface": "ebefeb" }
              }
          }
      ]

      // Reacts to both mode toggles and theme selection changes
      readonly property string activeTheme: Colours.light ? lightTheme : darkTheme

      // Guard: prevents _applyToSystem firing during initialization
      property bool _ready: false

      Component.onCompleted: {
          const c = GlobalConfig.colours
          if (c) {
              darkTheme = c.darkTheme ?? "dynamic"
              lightTheme = c.lightTheme ?? "dynamic"
          }
          _ready = true
          // Apply predefined theme on startup (dynamic re-applies itself via wallpaper)
          if (activeTheme !== "dynamic") _applyToSystem()
      }

      onActivethemeChanged: {
          if (_ready) _applyToSystem()
      }

      // Called from ColourSelect when user clicks a theme card
      function selectTheme(id) {
          if (Colours.light) lightTheme = id
          else darkTheme = id
          _savePrefs()
          _applyToSystem()
      }

      // Called from ColourSelect when user clicks "From Wallpaper"
      function selectDynamic() {
          darkTheme = "dynamic"
          lightTheme = "dynamic"
          _savePrefs()
          _applyToSystem()
      }

      function _savePrefs() {
          GlobalConfig.colours = { "darkTheme": darkTheme, "lightTheme": lightTheme }
      }

      function _applyToSystem() {
          const theme = Colours.light ? lightTheme : darkTheme
          const mode  = Colours.light ? "light" : "dark"
          if (theme === "dynamic") {
              Quickshell.execDetached(["caelestia", "scheme", "set", "-n", "dynamic"])
          } else {
              Quickshell.execDetached(["caelestia", "scheme", "set",
                                       "-n", theme, "-f", "default", "-m", mode])
          }
      }
  }
  ```

- [ ] **Commit**
  ```bash
  cd /tmp/caelestia-shell-dev
  git add services/ThemeEngine.qml
  git commit -m "feat: add ThemeEngine singleton for predefined colour theme management"
  ```

---

## Task 4: Create ThemeCard.qml

**Files:**
- Create: `modules/nexus/pages/wallandstyle/ThemeCard.qml`

A reusable card showing a 2×2 colour swatch and the theme name. Highlighted with a primary-coloured border when `active`.

- [ ] **Create the file** at `/tmp/caelestia-shell-dev/modules/nexus/pages/wallandstyle/ThemeCard.qml`:

  ```qml
  pragma ComponentBehavior: Bound

  import QtQuick
  import QtQuick.Layouts
  import Caelestia.Config
  import qs.components
  import qs.services
  import qs.modules.nexus.common

  Rectangle {
      id: root

      required property string themeId
      required property string themeName
      required property bool   active
      required property string previewPrimary
      required property string previewSecondary
      required property string previewBg
      required property string previewSurface

      signal clicked()

      implicitHeight: 60
      radius: 12
      color: Colours.palette.m3surfaceContainerHigh
      border.width: 2
      border.color: active ? Colours.palette.m3primary : "transparent"

      RowLayout {
          anchors.fill: parent
          anchors.margins: 12
          spacing: 12

          // 2×2 colour swatch
          Grid {
              columns: 2
              spacing: 3

              Repeater {
                  model: [root.previewPrimary, root.previewSecondary,
                          root.previewBg,      root.previewSurface]
                  delegate: Rectangle {
                      required property string modelData
                      width: 18; height: 18; radius: 3
                      color: "#" + modelData
                  }
              }
          }

          StyledText {
              Layout.fillWidth: true
              text: root.themeName
              font: Tokens.font.body.medium
              color: Colours.palette.m3onSurface
          }

          MaterialIcon {
              text: "check_circle"
              fontStyle: Tokens.font.icon.small
              color: Colours.palette.m3primary
              visible: root.active
          }
      }

      MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.clicked()
      }
  }
  ```

- [ ] **Commit**
  ```bash
  cd /tmp/caelestia-shell-dev
  git add modules/nexus/pages/wallandstyle/ThemeCard.qml
  git commit -m "feat: add ThemeCard component for colour theme grid"
  ```

---

## Task 5: Replace ColourSelect.qml Stub

**Files:**
- Replace: `modules/nexus/pages/wallandstyle/ColourSelect.qml`

The current stub (just "Page under construction") is replaced with a two-section layout:
- Section 1: source selector (From Wallpaper / Custom Theme) — mutually exclusive cards
- Section 2: theme grid (visible only in Custom Theme mode) + status row

- [ ] **Overwrite the file** at `/tmp/caelestia-shell-dev/modules/nexus/pages/wallandstyle/ColourSelect.qml`:

  ```qml
  pragma ComponentBehavior: Bound

  import QtQuick
  import QtQuick.Layouts
  import Caelestia.Config
  import qs.components
  import qs.services
  import qs.modules.nexus.common

  PageBase {
      id: root

      title: qsTr("Colours")
      isSubPage: true

      readonly property bool isCustom: ThemeEngine.activeTheme !== "dynamic"

      ColumnLayout {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: 16
          spacing: 0

          // ── Section 1: Colour Source ──────────────────────────────

          StyledText {
              Layout.bottomMargin: 8
              text: qsTr("COLOUR SOURCE")
              font: Tokens.font.label.small
              color: Colours.palette.m3primary
              letterSpacing: 1.2
          }

          RowLayout {
              Layout.fillWidth: true
              Layout.bottomMargin: 20
              spacing: 8

              // From Wallpaper card
              Rectangle {
                  Layout.fillWidth: true
                  implicitHeight: 76
                  radius: 12
                  color: !root.isCustom
                      ? Colours.palette.m3surfaceContainerHigh
                      : Colours.palette.m3surfaceContainer
                  border.width: 2
                  border.color: !root.isCustom ? Colours.palette.m3primary : "transparent"

                  ColumnLayout {
                      anchors.centerIn: parent
                      spacing: 4

                      MaterialIcon {
                          Layout.alignment: Qt.AlignHCenter
                          text: "wallpaper"
                          fontStyle: Tokens.font.icon.medium
                          color: !root.isCustom
                              ? Colours.palette.m3primary
                              : Colours.palette.m3onSurfaceVariant
                      }
                      StyledText {
                          Layout.alignment: Qt.AlignHCenter
                          text: qsTr("From Wallpaper")
                          font: Tokens.font.body.small
                          color: Colours.palette.m3onSurface
                      }
                      StyledText {
                          Layout.alignment: Qt.AlignHCenter
                          text: qsTr("auto · matugen")
                          font: Tokens.font.label.small
                          color: Colours.palette.m3onSurfaceVariant
                      }
                  }

                  MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: ThemeEngine.selectDynamic()
                  }
              }

              // Custom Theme card
              Rectangle {
                  Layout.fillWidth: true
                  implicitHeight: 76
                  radius: 12
                  color: root.isCustom
                      ? Colours.palette.m3surfaceContainerHigh
                      : Colours.palette.m3surfaceContainer
                  border.width: 2
                  border.color: root.isCustom ? Colours.palette.m3primary : "transparent"

                  ColumnLayout {
                      anchors.centerIn: parent
                      spacing: 4

                      MaterialIcon {
                          Layout.alignment: Qt.AlignHCenter
                          text: "palette"
                          fontStyle: Tokens.font.icon.medium
                          color: root.isCustom
                              ? Colours.palette.m3primary
                              : Colours.palette.m3onSurfaceVariant
                      }
                      StyledText {
                          Layout.alignment: Qt.AlignHCenter
                          text: qsTr("Custom Theme")
                          font: Tokens.font.body.small
                          color: Colours.palette.m3onSurface
                      }
                      StyledText {
                          Layout.alignment: Qt.AlignHCenter
                          text: root.isCustom ? qsTr("active") : qsTr("select below")
                          font: Tokens.font.label.small
                          color: root.isCustom
                              ? Colours.palette.m3primary
                              : Colours.palette.m3onSurfaceVariant
                      }
                  }

                  MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                          if (ThemeEngine.themeList.length > 0)
                              ThemeEngine.selectTheme(ThemeEngine.themeList[0].id)
                      }
                  }
              }
          }

          // ── Section 2: Theme Grid (visible only when Custom is active) ───

          ColumnLayout {
              Layout.fillWidth: true
              visible: root.isCustom
              spacing: 8

              StyledText {
                  Layout.bottomMargin: 4
                  text: qsTr("THEMES")
                  font: Tokens.font.label.small
                  color: Colours.palette.m3primary
                  letterSpacing: 1.2
              }

              Repeater {
                  model: ThemeEngine.themeList
                  ThemeCard {
                      required property var modelData
                      Layout.fillWidth: true

                      themeId:   modelData.id
                      themeName: modelData.name
                      active:    ThemeEngine.activeTheme === modelData.id

                      // Swatch colours update live when mode toggles
                      previewPrimary:   Colours.light
                          ? modelData.preview.light.primary
                          : modelData.preview.dark.primary
                      previewSecondary: Colours.light
                          ? modelData.preview.light.secondary
                          : modelData.preview.dark.secondary
                      previewBg:        Colours.light
                          ? modelData.preview.light.bg
                          : modelData.preview.dark.bg
                      previewSurface:   Colours.light
                          ? modelData.preview.light.surface
                          : modelData.preview.dark.surface

                      onClicked: ThemeEngine.selectTheme(modelData.id)
                  }
              }

              // Status row: per-mode current selections
              Rectangle {
                  Layout.fillWidth: true
                  Layout.topMargin: 8
                  implicitHeight: 52
                  radius: 8
                  color: Colours.palette.m3surfaceContainerLow

                  ColumnLayout {
                      anchors.fill: parent
                      anchors.margins: 10
                      spacing: 4

                      RowLayout {
                          StyledText {
                              text: "🌙 " + qsTr("Dark")
                              font: Tokens.font.label.small
                              color: Colours.palette.m3onSurfaceVariant
                          }
                          Item { Layout.fillWidth: true }
                          StyledText {
                              text: ThemeEngine.darkTheme === "dynamic"
                                    ? qsTr("Wallpaper") : ThemeEngine.darkTheme
                              font: Tokens.font.label.small
                              color: Colours.palette.m3primary
                          }
                      }

                      RowLayout {
                          StyledText {
                              text: "☀️ " + qsTr("Light")
                              font: Tokens.font.label.small
                              color: Colours.palette.m3onSurfaceVariant
                          }
                          Item { Layout.fillWidth: true }
                          StyledText {
                              text: ThemeEngine.lightTheme === "dynamic"
                                    ? qsTr("Wallpaper") : ThemeEngine.lightTheme
                              font: Tokens.font.label.small
                              color: Colours.palette.m3primary
                          }
                      }
                  }
              }
          }
      }
  }
  ```

- [ ] **Commit**
  ```bash
  cd /tmp/caelestia-shell-dev
  git add modules/nexus/pages/wallandstyle/ColourSelect.qml
  git commit -m "feat: replace ColourSelect stub with two-section theme chooser UI"
  ```

---

## Task 6: Push Shell Fork + Update nixos flake.lock + Rebuild

- [ ] **Push all commits to osmargm1202/shell**
  ```bash
  cd /tmp/caelestia-shell-dev
  git log --oneline origin/main..HEAD
  git push origin main
  ```
  Expected: 5 commits pushed (dark.txt, light.txt, flake.nix, ThemeEngine, ThemeCard, ColourSelect).

- [ ] **Update nixos flake.lock**
  ```bash
  cd /home/osmarg/Hobby/nixos
  nix flake update caelestia-shell
  git diff flake.lock | grep '"rev"'
  ```
  Expected: `caelestia-shell` rev updated to the new commit hash.

- [ ] **Rebuild** (takes ~5-10 min; recompiles caelestia-cli and caelestia-shell)
  ```bash
  sudo nixos-rebuild switch --flake .#orgm-hyprlandqs-caelestia 2>&1 | tail -20
  ```
  Expected: completes without errors; Quickshell restarts with new code.

- [ ] **Verify teal scheme registered**
  ```bash
  caelestia scheme list -n
  ```
  Expected: output includes `teal`.

- [ ] **Smoke test: apply teal dark**
  ```bash
  caelestia scheme set -n teal -f default -m dark
  ```
  Expected: shell colours immediately change to teal (bar, accents, backgrounds all teal-tinted).

- [ ] **Smoke test: apply teal light**
  ```bash
  caelestia scheme set -n teal -f default -m light
  ```
  Expected: shell switches to light mode with teal-tinted palette.

- [ ] **Restore dynamic scheme**
  ```bash
  caelestia scheme set -n dynamic
  ```

- [ ] **Open UI**: Nexus > Wallpaper & Style > Colours
  Verify:
  - Two source cards ("From Wallpaper" and "Custom Theme") are visible
  - Clicking "Custom Theme" → theme grid appears with Teal card showing 2×2 swatch
  - Clicking Teal card → colours change, card shows check icon
  - Status row updates to show "Dark: teal" / "Light: teal"
  - Toggling dark ↔ light mode → ThemeEngine auto-applies saved theme for new mode

- [ ] **Commit nixos flake.lock**
  ```bash
  cd /home/osmarg/Hobby/nixos
  git add flake.lock
  git commit -m "chore: update caelestia-shell — ThemeEngine + Teal scheme + ColourSelect UI"
  ```

---

## Troubleshooting

### postInstall not finding site-packages
If `$schemeDir` expands to nothing (wrong Python version glob), check:
```bash
ls $(nix build .#caelestia-shell --print-out-paths 2>/dev/null)/... # or check the nix store path
```
Fix: replace the glob with the explicit version `python3.13` if needed.

### ThemeEngine not found in ColourSelect
If QML logs "ThemeEngine is not a type", verify:
- `ThemeEngine.qml` is in `services/` and has `pragma Singleton`
- Quickshell restarts after rebuild (kill/restart the shell process)

### GlobalConfig.colours write not persisting
If `shell.json` doesn't update, check if `Caelestia.Config`'s `GlobalConfig` supports top-level object writes. Fallback: use a separate file:
```qml
// In ThemeEngine._savePrefs():
Quickshell.execDetached(["sh", "-c",
    `printf '{"darkTheme":"${darkTheme}","lightTheme":"${lightTheme}"}' > ~/.config/caelestia/theme-prefs.json`])
```
And read it back with `FileView` in `Component.onCompleted`.

### caelestia scheme set -n teal fails (unknown scheme)
Verify the override ran: check that `teal/default/dark.txt` exists in the CLI's nix store path:
```bash
find /nix/store/*caelestia-cli* -name 'dark.txt' -path '*/teal/*' 2>/dev/null
```
If not found, the `overrideAttrs` might not have a `postInstall` phase — check the CLI's derivation type.

---

## Adding Future Themes

1. Add colour files to `osmargm1202/shell/themes/<name>/default/dark.txt` and `light.txt`
   (generate with: `python3 -c "..."` using `hex_to_hct('<seed>') + gen_scheme()`)
2. Add the theme object to `ThemeEngine.qml`'s `themeList` array with preview colours
3. Push to fork → `nix flake update caelestia-shell` → `sudo nixos-rebuild switch ...`
