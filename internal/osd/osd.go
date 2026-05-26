package osd

import "fmt"

type Command struct {
	Name string
	Args []string
}

type DeviceState struct {
	Volume int
	Muted  bool
}

type NotifyPayload struct {
	App       string
	SyncID    string
	Value     int
	Title     string
	TimeoutMS int
}

type Plan struct {
	Command Command
	Notify  NotifyPayload
}

func PlanVolume(action string, state DeviceState) (Plan, error) {
	args, err := pamixerArgs(action, false)
	if err != nil {
		return Plan{}, fmt.Errorf("usage: volume-osd up|down|mute")
	}
	title := fmt.Sprintf(" Volume %d%%", state.Volume)
	if state.Muted {
		title = "󰝟 Volume muted"
	}
	return Plan{Command: Command{Name: "pamixer", Args: args}, Notify: NotifyPayload{App: "osd-volume", SyncID: "osd-volume", Value: state.Volume, Title: title, TimeoutMS: 900}}, nil
}

func PlanMic(action string, state DeviceState) (Plan, error) {
	args, err := pamixerArgs(action, true)
	if err != nil {
		return Plan{}, fmt.Errorf("usage: mic-volume-osd up|down|mute")
	}
	title := fmt.Sprintf("󰍬 Mic %d%%", state.Volume)
	if state.Muted {
		title = "󰍭 Mic muted"
	}
	return Plan{Command: Command{Name: "pamixer", Args: args}, Notify: NotifyPayload{App: "osd-mic", SyncID: "osd-mic", Value: state.Volume, Title: title, TimeoutMS: 900}}, nil
}

func PlanBrightness(action string, percent int) (Plan, error) {
	value := ""
	switch action {
	case "up":
		value = "5%+"
	case "down":
		value = "5%-"
	default:
		return Plan{}, fmt.Errorf("usage: brightness-osd up|down")
	}
	title := fmt.Sprintf("󰃠 Brightness %d%%", percent)
	return Plan{Command: Command{Name: "brightnessctl", Args: []string{"set", value}}, Notify: NotifyPayload{App: "osd-brightness", SyncID: "osd-brightness", Value: percent, Title: title, TimeoutMS: 900}}, nil
}

func pamixerArgs(action string, mic bool) ([]string, error) {
	args := []string{}
	if mic {
		args = append(args, "--default-source")
	}
	switch action {
	case "up":
		args = append(args, "--allow-boost", "--set-limit", "150", "-i", "3")
	case "down":
		args = append(args, "--allow-boost", "--set-limit", "150", "-d", "3")
	case "mute":
		args = append(args, "-t")
	default:
		return nil, fmt.Errorf("unknown action")
	}
	return args, nil
}
