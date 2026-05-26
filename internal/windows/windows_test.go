package windows

import "testing"

func TestClientRowsFromHyprctlJSONBuildsCompatibilityLabels(t *testing.T) {
	input := `[
		{"address":"0xabc","workspace":{"name":"2"},"class":"kitty","title":"term"},
		{"address":"0xdef","workspace":{"name":"special"},"class":"zen-browser","title":"Docs"}
	]`

	rows, err := ClientRowsFromJSON([]byte(input))

	if err != nil {
		t.Fatalf("ClientRowsFromJSON() error = %v", err)
	}
	want := []ClientRow{
		{Address: "0xabc", Label: "[2] kitty — term"},
		{Address: "0xdef", Label: "[special] zen-browser — Docs"},
	}
	if len(rows) != len(want) {
		t.Fatalf("rows length = %d, want %d: %#v", len(rows), len(want), rows)
	}
	for i := range want {
		if rows[i] != want[i] {
			t.Fatalf("rows[%d] = %#v, want %#v", i, rows[i], want[i])
		}
	}
}

func TestFocusCommandBuildsHyprctlLuaDispatch(t *testing.T) {
	command, ok := FocusCommand("0xabc")

	if !ok {
		t.Fatalf("FocusCommand() ok = false, want true")
	}
	if command.Name != "hyprctl" {
		t.Fatalf("command name = %q, want hyprctl", command.Name)
	}
	want := []string{"dispatch", `hl.dsp.focus({ window = "address:0xabc" })`}
	if len(command.Args) != len(want) {
		t.Fatalf("args length = %d, want %d: %#v", len(command.Args), len(want), command.Args)
	}
	for i := range want {
		if command.Args[i] != want[i] {
			t.Fatalf("arg[%d] = %q, want %q", i, command.Args[i], want[i])
		}
	}
}

func TestKillCandidatesFiltersDuplicateSmallAndForeignProcesses(t *testing.T) {
	input := `[
		{"pid":101,"class":"kitty","title":"term","workspace":{"name":"1"}},
		{"pid":101,"class":"kitty","title":"term duplicate","workspace":{"name":"1"}},
		{"pid":202,"class":"tiny","title":"small","workspace":{"name":"2"}},
		{"pid":303,"class":"rootapp","title":"foreign","workspace":{"name":"3"}}
	]`
	rss := map[int]int{101: 20480, 202: 5120, 303: 40960}
	owned := map[int]bool{101: true, 202: true, 303: false}

	candidates, err := KillCandidatesFromJSON([]byte(input), 10240, func(pid int) (int, bool) {
		return rss[pid], owned[pid]
	})

	if err != nil {
		t.Fatalf("KillCandidatesFromJSON() error = %v", err)
	}
	if len(candidates) != 1 {
		t.Fatalf("candidates length = %d, want 1: %#v", len(candidates), candidates)
	}
	wantLabel := "   20.0 MB  PID 101      [1] kitty — term"
	if candidates[0].PID != 101 || candidates[0].RSSKB != 20480 || candidates[0].Label != wantLabel {
		t.Fatalf("candidate = %#v, want PID 101 RSS 20480 label %q", candidates[0], wantLabel)
	}
}
