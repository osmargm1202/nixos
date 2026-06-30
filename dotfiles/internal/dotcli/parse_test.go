package dotcli

import "testing"

func TestParseStatusHost(t *testing.T) {
	cmd, err := Parse([]string{"status", "--host", "lenovo"})
	if err != nil {
		t.Fatal(err)
	}
	if cmd.Name != "status" || cmd.Host != "lenovo" || cmd.Scope != "host" {
		t.Fatalf("unexpected command: %+v", cmd)
	}
}

func TestParseLegacyStatus(t *testing.T) {
	cmd, err := Parse([]string{"--status", "--host", "orgm"})
	if err != nil {
		t.Fatal(err)
	}
	if cmd.Name != "status" || cmd.Host != "orgm" {
		t.Fatalf("unexpected command: %+v", cmd)
	}
}

func TestParseSyncTarget(t *testing.T) {
	cmd, err := Parse([]string{"sync", ".local/bin/tool", "--dry-run"})
	if err != nil {
		t.Fatal(err)
	}
	if cmd.Name != "sync" || cmd.Target != ".local/bin/tool" || !cmd.DryRun {
		t.Fatalf("unexpected command: %+v", cmd)
	}
}

func TestParseSyncRejectsMultipleTargets(t *testing.T) {
	_, err := Parse([]string{"sync", ".local/bin/one", ".local/bin/two"})
	if err == nil {
		t.Fatal("expected multiple-target error")
	}
}

func TestParseAddTargetAndScope(t *testing.T) {
	cmd, err := Parse([]string{"add", "~/.config/example", "--shared"})
	if err != nil {
		t.Fatal(err)
	}
	if cmd.Name != "add" || cmd.Target != "~/.config/example" || cmd.Scope != "shared" {
		t.Fatalf("unexpected command: %+v", cmd)
	}
}

func TestParsePorcelainImpliesNoColor(t *testing.T) {
	cmd, err := Parse([]string{"diff", "--host", "lenovo", "--porcelain"})
	if err != nil {
		t.Fatal(err)
	}
	if !cmd.Porcelain || !cmd.NoColor {
		t.Fatalf("porcelain should imply no color: %+v", cmd)
	}
}

func TestParseRejectsMultipleCommands(t *testing.T) {
	_, err := Parse([]string{"status", "diff", "--host", "lenovo"})
	if err == nil {
		t.Fatal("expected multiple-command error")
	}
}

func TestRequireHost(t *testing.T) {
	cmd := Command{Name: "status"}
	if err := cmd.RequireHost(); err == nil {
		t.Fatal("expected missing host error")
	}
}
