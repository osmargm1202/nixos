package main

import (
	"path/filepath"
	"testing"
)

func TestWaylandLayerSelectionAndPrecedence(t *testing.T) {
	for _, profile := range []string{"sway", "hyprland", "ryoku", "i3", "terminal"} {
		t.Run(profile, func(t *testing.T) {
			r := fixture(t)
			r.Profile = profile
			rel := ".config/demo/wayland"
			put(t, filepath.Join(r.Repository, "dotfiles/config/profiles/wayland", rel), "shared")
			must(t, r.collect())
			source, found := r.Files[rel]
			want := profile == "sway" || profile == "hyprland"
			if found != want {
				t.Fatalf("profile %s shared selection = %v, want %v", profile, found, want)
			}
			if !want {
				return
			}
			if textAt(t, source) != "shared" {
				t.Fatal("shared source lost")
			}
			for _, layer := range []string{"profiles/" + profile, "users/user/profiles/" + profile, "hosts/host/profiles/" + profile} {
				put(t, filepath.Join(r.Repository, "dotfiles/config", layer, rel), layer)
				must(t, r.collect())
				if textAt(t, r.Files[rel]) != layer {
					t.Fatalf("%s must override shared layer", layer)
				}
			}
		})
	}
}

func TestWaylandCollectionDoesNotChangeEditedHome(t *testing.T) {
	r := fixture(t)
	rel := ".config/demo/settings"
	put(t, filepath.Join(r.Home, rel), "my edits")
	put(t, filepath.Join(r.Repository, "dotfiles/config/profiles/wayland", rel), "shared")
	must(t, r.collect())
	if textAt(t, filepath.Join(r.Home, rel)) != "my edits" {
		t.Fatal("collection changed HOME")
	}
}
