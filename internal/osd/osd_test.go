package osd

import "testing"

func TestVolumeActionPlansPamixerAndNotifyPayload(t *testing.T) {
	plan, err := PlanVolume("up", DeviceState{Volume: 42, Muted: false})

	if err != nil {
		t.Fatalf("PlanVolume(up) error = %v", err)
	}
	wantArgs := []string{"--allow-boost", "--set-limit", "150", "-i", "3"}
	assertCommand(t, plan.Command, "pamixer", wantArgs)
	wantNotify := NotifyPayload{App: "osd-volume", SyncID: "osd-volume", Value: 42, Title: " Volume 42%", TimeoutMS: 900}
	if plan.Notify != wantNotify {
		t.Fatalf("notify = %#v, want %#v", plan.Notify, wantNotify)
	}
}

func TestMicMutePlansDefaultSourceToggleAndMutedPayload(t *testing.T) {
	plan, err := PlanMic("mute", DeviceState{Volume: 7, Muted: true})

	if err != nil {
		t.Fatalf("PlanMic(mute) error = %v", err)
	}
	wantArgs := []string{"--default-source", "-t"}
	assertCommand(t, plan.Command, "pamixer", wantArgs)
	wantNotify := NotifyPayload{App: "osd-mic", SyncID: "osd-mic", Value: 7, Title: "󰍭 Mic muted", TimeoutMS: 900}
	if plan.Notify != wantNotify {
		t.Fatalf("notify = %#v, want %#v", plan.Notify, wantNotify)
	}
}

func TestBrightnessDownPlansBrightnessctlAndNotifyPayload(t *testing.T) {
	plan, err := PlanBrightness("down", 66)

	if err != nil {
		t.Fatalf("PlanBrightness(down) error = %v", err)
	}
	assertCommand(t, plan.Command, "brightnessctl", []string{"set", "5%-"})
	wantNotify := NotifyPayload{App: "osd-brightness", SyncID: "osd-brightness", Value: 66, Title: "󰃠 Brightness 66%", TimeoutMS: 900}
	if plan.Notify != wantNotify {
		t.Fatalf("notify = %#v, want %#v", plan.Notify, wantNotify)
	}
}

func TestInvalidOSDActionsReturnUsageErrors(t *testing.T) {
	if _, err := PlanVolume("louder", DeviceState{}); err == nil || err.Error() != "usage: volume-osd up|down|mute" {
		t.Fatalf("PlanVolume invalid error = %v, want volume usage", err)
	}
	if _, err := PlanBrightness("mute", 0); err == nil || err.Error() != "usage: brightness-osd up|down" {
		t.Fatalf("PlanBrightness invalid error = %v, want brightness usage", err)
	}
}

func assertCommand(t *testing.T, command Command, name string, args []string) {
	t.Helper()
	if command.Name != name {
		t.Fatalf("command name = %q, want %q", command.Name, name)
	}
	if len(command.Args) != len(args) {
		t.Fatalf("args length = %d, want %d: %#v", len(command.Args), len(args), command.Args)
	}
	for i := range args {
		if command.Args[i] != args[i] {
			t.Fatalf("arg[%d] = %q, want %q", i, command.Args[i], args[i])
		}
	}
}
