package menu

import "testing"

func TestModelMainListsCompatibilityItems(t *testing.T) {
	model, ok := Model("main")
	if !ok {
		t.Fatalf("Model(main) ok = false")
	}
	got := Labels(model.Items)
	want := []string{"󰀻 Apps", "󰒓 Tools", "󱐋 Performance", "󰖩 WiFi", "󰂯 Bluetooth", "󰍉 Search", "󰌌 Keybinds", "󰒓 System", "󰑓 Reload Dock", "󰐥 Power", "󰌌 Keyboard", "󰣆 Web App Maker", "󰅖 Quit"}
	if len(got) != len(want) {
		t.Fatalf("labels len = %d (%v), want %d (%v)", len(got), got, len(want), want)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("labels[%d] = %q, want %q", i, got[i], want[i])
		}
	}
}

func TestPlanSelectionBuildsCanonicalOrgmHyprActions(t *testing.T) {
	tests := []struct {
		name      string
		menuName  string
		selection string
		want      ActionPlan
	}{
		{
			name:      "main tools delegates to orgm-hypr menu tools",
			menuName:  "main",
			selection: "󰒓 Tools",
			want:      ActionPlan{Command: Command{Name: "orgm-hypr", Args: []string{"menu", "tools"}}},
		},
		{
			name:      "main apps uses orgm-hypr launcher",
			menuName:  "main",
			selection: "󰀻 Apps",
			want:      ActionPlan{Command: Command{Name: "orgm-hypr", Args: []string{"launcher", "apps"}}},
		},
		{
			name:      "tools search files uses orgm-hypr file command",
			menuName:  "tools",
			selection: "󰍉 Search files",
			want:      ActionPlan{Command: Command{Name: "orgm-hypr", Args: []string{"file", "open", "--launcher", "fuzzel"}}},
		},
		{
			name:      "power lock uses orgm-hypr session command",
			menuName:  "power",
			selection: "󰌾 Lock",
			want:      ActionPlan{Command: Command{Name: "orgm-hypr", Args: []string{"session", "lock", "--force"}}},
		},
		{
			name:      "keyboard latam switches explicit layout",
			menuName:  "keyboard",
			selection: "󰌌 Latam",
			want:      ActionPlan{Command: Command{Name: "hyprctl", Args: []string{"switchxkblayout", "all", "1"}}},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, ok := PlanSelection(tt.menuName, tt.selection)
			if !ok {
				t.Fatalf("PlanSelection(%q, %q) ok = false", tt.menuName, tt.selection)
			}
			if !plansEqual(got, tt.want) {
				t.Fatalf("PlanSelection() = %#v, want %#v", got, tt.want)
			}
		})
	}
}

func TestPlanSelectionMarksPowerActionsDestructive(t *testing.T) {
	tests := []struct {
		selection string
		confirm   string
		args      []string
	}{
		{selection: "󰤄 Suspend", confirm: "suspend", args: []string{"suspend"}},
		{selection: "󰒲 Hibernate", confirm: "hibernate", args: []string{"hibernate"}},
		{selection: "󰜉 Reboot", confirm: "reboot", args: []string{"reboot"}},
	}
	for _, tt := range tests {
		t.Run(tt.confirm, func(t *testing.T) {
			got, ok := PlanSelection("power", tt.selection)
			if !ok {
				t.Fatalf("PlanSelection(power, %q) ok = false", tt.selection)
			}
			want := ActionPlan{Command: Command{Name: "systemctl", Args: tt.args}, Destructive: true, Confirmation: tt.confirm}
			if !plansEqual(got, want) {
				t.Fatalf("PlanSelection() = %#v, want %#v", got, want)
			}
		})
	}
}

func TestSystemMenuUsesCanonicalOrgmHyprCommands(t *testing.T) {
	tests := []struct {
		selection string
		want      ActionPlan
	}{
		{selection: "󰑓 Reload Hyprland", want: ActionPlan{Command: Command{Name: "hyprctl", Args: []string{"reload"}}}},
		{selection: "󰑓 Reload Dock", want: ActionPlan{Command: Command{Name: "orgm-hypr", Args: []string{"dock", "start", "reload"}}}},
	}
	for _, tt := range tests {
		t.Run(tt.selection, func(t *testing.T) {
			got, ok := PlanSelection("system", tt.selection)
			if !ok {
				t.Fatalf("PlanSelection(system, %q) ok = false", tt.selection)
			}
			if !plansEqual(got, tt.want) {
				t.Fatalf("PlanSelection() = %#v, want %#v", got, tt.want)
			}
		})
	}
}

func TestKeybindingCategoriesExposeMetadataAndEntries(t *testing.T) {
	categories := KeybindingCategories()
	if len(categories) < 6 {
		t.Fatalf("KeybindingCategories len = %d, want at least 6", len(categories))
	}
	first := categories[0]
	if first.ID != "launchers" || first.Title != "Launchers" || first.Icon == "" {
		t.Fatalf("first category = %#v, want launchers metadata", first)
	}
	if len(first.Entries) == 0 {
		t.Fatalf("launchers entries empty")
	}
	if first.Entries[0].Key != "Win+/" || first.Entries[0].Command != "orgm-hypr helper toggle" {
		t.Fatalf("first launcher entry = %#v, want Win+/ orgm-hypr helper toggle", first.Entries[0])
	}
}

func TestKeybindingEntriesFilterCategories(t *testing.T) {
	launchers := KeybindingEntries("launchers")
	if len(launchers) == 0 {
		t.Fatalf("launchers entries empty")
	}
	if launchers[0].Key != "Win+/" || launchers[0].Command != "orgm-hypr helper toggle" {
		t.Fatalf("first launcher entry = %#v, want Win+/ orgm-hypr helper toggle", launchers[0])
	}
	media := KeybindingEntries("media")
	if len(media) == 0 || media[0].Command != "orgm-hypr osd volume up/down" {
		t.Fatalf("media entries = %#v, want first orgm-hypr osd volume up/down", media)
	}
}

func plansEqual(a, b ActionPlan) bool {
	if a.Command.Name != b.Command.Name || a.Destructive != b.Destructive || a.Confirmation != b.Confirmation || len(a.Command.Args) != len(b.Command.Args) {
		return false
	}
	for i := range a.Command.Args {
		if a.Command.Args[i] != b.Command.Args[i] {
			return false
		}
	}
	return true
}
