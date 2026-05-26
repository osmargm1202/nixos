package dock

import (
	"reflect"
	"testing"
)

func TestStartArgsUseCanonicalOrgmHyprMenuByDefault(t *testing.T) {
	args := StartArgs(Env{
		Home: "/home/osmarg",
	})

	want := []string{
		"-r",
		"-p", "right",
		"-a", "center",
		"-i", "56",
		"-x",
		"-mr", "8",
		"-mt", "0",
		"-mb", "0",
		"-lp", "start",
		"-ico", "/home/osmarg/.local/share/icons/nixos.svg",
		"-c", "orgm-hypr menu main",
	}
	if !reflect.DeepEqual(args, want) {
		t.Fatalf("StartArgs(default) = %#v, want %#v", args, want)
	}
}

func TestStartArgsHonorWrapperEnvironmentOverrides(t *testing.T) {
	args := StartArgs(Env{
		Home:             "/home/osmarg",
		IconSize:         "64",
		MarginRight:      "12",
		MarginTop:        "3",
		MarginBottom:     "5",
		LauncherPosition: "end",
		LauncherIcon:     "/tmp/menu.svg",
		LauncherCommand:  "custom-menu",
	})

	want := []string{
		"-r", "-p", "right", "-a", "center", "-i", "64", "-x", "-mr", "12", "-mt", "3", "-mb", "5", "-lp", "end", "-ico", "/tmp/menu.svg", "-c", "custom-menu",
	}
	if !reflect.DeepEqual(args, want) {
		t.Fatalf("StartArgs(overrides) = %#v, want %#v", args, want)
	}
}

func TestPlanStartCapturesIdempotentCompatibilityBehavior(t *testing.T) {
	plan := PlanStart(StartState{BinaryFound: false})
	if plan.ExitCode != 1 || len(plan.Notifications) != 1 || len(plan.ExecArgs) != 0 {
		t.Fatalf("missing binary plan = %#v, want notify and exit 1", plan)
	}

	plan = PlanStart(StartState{BinaryFound: true, AlreadyRunning: true})
	if plan.ExitCode != 0 || len(plan.ExecArgs) != 0 || plan.KillExisting {
		t.Fatalf("already running plan = %#v, want no-op exit 0", plan)
	}

	plan = PlanStart(StartState{BinaryFound: true, AlreadyRunning: true, Reload: true})
	if plan.ExitCode != 0 || !plan.KillExisting || len(plan.ExecArgs) != 0 {
		t.Fatalf("reload running plan = %#v, want kill then no exec", plan)
	}
}
