package zen

import "testing"

func TestFocusAddressFromClientsChoosesBestZenWindow(t *testing.T) {
	input := `[
		{"address":"0xold","class":"app.zen_browser.zen","focusHistoryID":7},
		{"address":"0xnew","class":"zen-browser","focusHistoryID":2},
		{"address":"0xterm","class":"kitty","focusHistoryID":1}
	]`

	address, ok, err := FocusAddressFromClients([]byte(input))

	if err != nil {
		t.Fatalf("FocusAddressFromClients() error = %v", err)
	}
	if !ok || address != "0xnew" {
		t.Fatalf("address = %q ok = %t, want 0xnew true", address, ok)
	}
}

func TestOpenCommandUsesNewTabWhenZenAlreadyRunning(t *testing.T) {
	command, ok := OpenCommand(InstallState{Flatpak: true, FlatpakZen: true}, true)

	if !ok {
		t.Fatalf("OpenCommand() ok = false, want true")
	}
	if command.Name != "flatpak" {
		t.Fatalf("command name = %q, want flatpak", command.Name)
	}
	want := []string{"run", "app.zen_browser.zen", "--new-tab", "about:blank"}
	if len(command.Args) != len(want) {
		t.Fatalf("args length = %d, want %d: %#v", len(command.Args), len(want), command.Args)
	}
	for i := range want {
		if command.Args[i] != want[i] {
			t.Fatalf("arg[%d] = %q, want %q", i, command.Args[i], want[i])
		}
	}
}

func TestOpenCommandFallsBackToNativeAndReportsMissingInstall(t *testing.T) {
	command, ok := OpenCommand(InstallState{ZenBrowser: true}, false)
	if !ok || command.Name != "zen-browser" || len(command.Args) != 0 {
		t.Fatalf("native command = %#v ok=%t, want zen-browser no args", command, ok)
	}

	_, ok = OpenCommand(InstallState{}, false)
	if ok {
		t.Fatalf("OpenCommand(missing) ok = true, want false")
	}
}
