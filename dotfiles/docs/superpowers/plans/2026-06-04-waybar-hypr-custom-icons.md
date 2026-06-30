# Waybar-Hypr Custom Icons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the texture experiment with a dark translucent Waybar-Hypr bar and SVG image icons for each top-right custom button.

**Architecture:** Keep regular Waybar unchanged. Store SVG icons in `config/shared/.config/waybar-hypr/icons/`. Update `style.css` so top/bottom bars use dark translucent blue with fine horizontal borders, no texture, no internal dividers, and custom top-right modules render their icon through `background-image` while preserving existing click/tooltip behavior.

**Tech Stack:** Waybar CSS, SVG, shell verification.

---

## Tasks

### Task 1: Add verification test

- [x] Create `tests/helpers/waybar-hypr-custom-icons.bats.sh`.
- [x] Assert the bar uses `rgba(2, 10, 24, 0.78)`.
- [x] Assert no texture background or 2px internal dividers remain.
- [x] Assert all eight custom icons exist and are referenced by CSS.
- [x] Run the test and observe failure before implementation.

### Task 2: Add SVG icons

- [x] Create `config/shared/.config/waybar-hypr/icons/`.
- [x] Add SVG line icons for `theme_toggle`, `wallpaper`, `usb_devices`, `nixclean`, `hardware_fetch`, `pi_status`, `headset_reconnect`, and `logout_menu`.
- [x] Use cyan/blue strokes on transparent background.

### Task 3: Update Waybar-Hypr CSS

- [x] Remove texture/background-image usage from bar styling.
- [x] Set top/bottom bar background to `rgba(2, 10, 24, 0.78)`.
- [x] Use fine top/bottom border lines instead of full rectangular borders.
- [x] Remove internal divider borders.
- [x] Add `background-image: url("icons/<button>.svg")` for each custom top-right module.
- [x] Hide glyph text for custom icon buttons with transparent color and `font-size: 0`.

### Task 4: Verify and live test

- [x] Run `bash tests/helpers/waybar-hypr-custom-icons.bats.sh`; expect PASS.
- [x] Run `go test ./internal/orgmtheme ./cmd/orgm-themes -count=1`; expect PASS.
- [x] Apply live only to `~/.config/waybar-hypr/style.css`, `~/.config/waybar-hypr/icons/*.svg`, and remove the active texture rule from `~/.config/waybar-hypr/orgm-current.css`.
- [x] Restart/trigger Waybar-Hypr watcher and confirm log contains `Bar configured`.
