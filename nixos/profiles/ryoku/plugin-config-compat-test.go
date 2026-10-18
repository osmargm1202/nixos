package main

import (
	"strings"
	"testing"
)

func TestHubImageBorderGapsUseLuaTypes(t *testing.T) {
	for _, tc := range []struct{ input, want string }{
		{"8", "8"},
		{"8,8,8,8", "{ top = 8, right = 8, bottom = 8, left = 8 }"},
		{"1 2", "{ top = 1, right = 2, bottom = 1, left = 2 }"},
		{"1, 2, 3", "{ top = 1, right = 2, bottom = 3, left = 2 }"},
		{"-1,2,3,4", "{ top = -1, right = 2, bottom = 3, left = 4 }"},
		{"bad", "0"}, {"", "0"},
	} {
		if got := luaCSSGap(tc.input); got != tc.want {
			t.Errorf("gap %q: got %s, want %s", tc.input, got, tc.want)
		}
	}
}

func TestImageBordersOnlyEmitsRegisteredOptions(t *testing.T) {
	o := defaultOverrides()
	o.Plugins.Imgborders.Enabled = true
	o.Plugins.Imgborders.Sizes = "1,2,3,4"
	o.Plugins.Imgborders.Insets = "0"
	for _, block := range pluginBlocks(o) {
		if block.id != "imgborders" {
			continue
		}
		if strings.Contains(block.config, "enabled =") || strings.Contains(block.config, `sizes = "`) {
			t.Fatalf("unregistered option or wrong Lua type: %s", block.config)
		}
		if !strings.Contains(block.config, "sizes = { top = 1, right = 2, bottom = 3, left = 4 }") {
			t.Fatalf("lost edge values: %s", block.config)
		}
		return
	}
	t.Fatal("enabled image borders block missing")
}

func TestGlassControlsOverrideSelectedPreset(t *testing.T) {
	hg := defaultOverrides().Plugins.Hyprglass
	hg.Preset, hg.BlurStrength, hg.Opacity, hg.Brightness = "glass", 3, 0.4, 0.7
	got := hubGlassPreset(hg)
	for _, want := range []string{`apply_preset("ryoku-hub"`, `inherits = "glass"`, "blur_strength = 3", "glass_opacity = 0.4", "dark = { brightness = 0.7 }", "light = { brightness = 0.7 }"} {
		if !strings.Contains(got, want) {
			t.Errorf("missing %s in %s", want, got)
		}
	}
}

func TestFocusMouseRemainsAnExplicitHubChoice(t *testing.T) {
	hf := Hyprfocus{Mode: "flash"}
	if focusMouseMode(hf) != "none" {
		t.Fatal("changed the existing mouse preference")
	}
	hf.Mouse = true
	if focusMouseMode(hf) != "flash" {
		t.Fatal("mouse choice ignored")
	}
	hf.Mode = "bounce"
	if focusMouseMode(hf) != "shrink" {
		t.Fatal("old Bounce name was not translated")
	}
}
