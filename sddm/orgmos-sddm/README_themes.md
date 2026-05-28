# SDDM ORGMOS Theme - Color Variations

## Available Themes

### 1. Default (theme.conf.user) 🌌
- Original ORGMOS theme with sky blue accents
- Background: `#0a1929` (dark navy)
- Accent: `#87ceeb` (sky blue)

### 2. Tokyo Night (tokyo-night.conf) ⭐
- Dark theme inspired by Tokyo Night VSCode theme
- Background: `#1a1b26` (dark blue-black)
- Accent: `#7dcfff` (bright cyan/sky blue) - **Bright sky blue button**

### 3. Panther (panther.conf) 🐾
- Dark minimal theme
- Background: `#111111` (nearly black)
- Accent: varies

### 4. Lynx (lynx.conf) 🦁
- Light theme
- Background: `#F9F9F9` (off-white)
- Accent: varies
- Uses special lynx variants of icons

## Usage

### After Installing SDDM Theme

Theme sources now live in this NixOS repository:

```bash
cd /home/osmarg/Hobby/nixos/sddm/orgmos-sddm
```

`metadata.desktop` loads `theme.conf`. This repository tracks `theme.conf` as the default Tokyo Night variant.

### Manual Method

```bash
# Copy desired theme to theme.conf
sudo cp tokyo-night.conf /usr/share/sddm/themes/orgmos-sddm/theme.conf

# Restart SDDM
sudo systemctl restart sddm
```

## Installation

The themes are installed via:
```bash
sudo ./Apps/install_sddm.sh
```

The installed theme needs `theme.conf` next to `metadata.desktop`. Copy one of the tracked variants to `theme.conf` to select your preferred theme.

## Theme Structure

Each `.conf` file contains:
- `backgroundColor`: Main background
- `boxColor`: Login box background
- `borderColor`: Border colors
- `buttonColor`: Button backgrounds
- `textColor`: Main text
- `secondaryTextColor`: Secondary text
- `accentColor`: **Login button color** ⭐
- `onAccentColor`: Text on login button
- `dangerColor`: Error messages

## Recommended: Tokyo Night ⭐

Tokyo Night offers the best balance of:
- Dark, comfortable background
- Bright sky blue login button (`#7dcfff`)
- Excellent contrast for readability
- Modern aesthetic
