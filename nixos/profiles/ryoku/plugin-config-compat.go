package main

import (
	"fmt"
	"strconv"
	"strings"
)

// Preset-specific values win over global plugin options. Give the Hub its own
// child preset so its sliders remain effective for every selected personality.
func hubGlassPreset(hg Hyprglass) string {
	return fmt.Sprintf("  hl.plugin.hyprglass.apply_preset(\"ryoku-hub\", { inherits = %s, blur_strength = %s, glass_opacity = %s, tint_color = 0x%s, dark = { brightness = %s }, light = { brightness = %s } })\n",
		luaStr(hg.Preset), luaNum(hg.BlurStrength), luaNum(hg.Opacity), luaHex8(hg.Tint), luaNum(hg.Brightness), luaNum(hg.Brightness))
}

func focusMouseMode(hf Hyprfocus) string {
	if !hf.Mouse {
		return "none"
	}
	if hf.Mode == "bounce" {
		return "shrink"
	}
	return hf.Mode
}

// The Hub stores CSS gaps as text. Hyprland's Lua API accepts an integer or
// named sides, not the comma-separated strings accepted by hyprlang.
func luaCSSGap(raw string) string {
	parts := strings.Fields(strings.ReplaceAll(raw, ",", " "))
	if len(parts) == 0 || len(parts) > 4 {
		return "0"
	}
	values := make([]int, len(parts))
	for i, part := range parts {
		n, err := strconv.Atoi(part)
		if err != nil {
			return "0"
		}
		values[i] = n
	}
	if len(values) == 1 {
		return strconv.Itoa(values[0])
	}
	top, right, bottom, left := values[0], values[1], values[0], values[1]
	if len(values) > 2 {
		bottom = values[2]
	}
	if len(values) > 3 {
		left = values[3]
	}
	return fmt.Sprintf("{ top = %d, right = %d, bottom = %d, left = %d }", top, right, bottom, left)
}
