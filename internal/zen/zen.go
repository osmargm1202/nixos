package zen

import (
	"encoding/json"
	"sort"
)

type Command struct {
	Name string
	Args []string
}

type InstallState struct {
	Flatpak    bool
	FlatpakZen bool
	ZenBrowser bool
	Zen        bool
}

type client struct {
	Address        string `json:"address"`
	Class          string `json:"class"`
	FocusHistoryID int    `json:"focusHistoryID"`
}

func FocusAddressFromClients(data []byte) (string, bool, error) {
	var clients []client
	if err := json.Unmarshal(data, &clients); err != nil {
		return "", false, err
	}
	matches := []client{}
	for _, c := range clients {
		if c.Address == "" || !isZenClass(c.Class) {
			continue
		}
		if c.FocusHistoryID == 0 {
			c.FocusHistoryID = 999999
		}
		matches = append(matches, c)
	}
	if len(matches) == 0 {
		return "", false, nil
	}
	sort.SliceStable(matches, func(i, j int) bool { return matches[i].FocusHistoryID < matches[j].FocusHistoryID })
	return matches[0].Address, true, nil
}

func OpenCommand(state InstallState, alreadyRunning bool) (Command, bool) {
	args := []string{}
	if alreadyRunning {
		args = []string{"--new-tab", "about:blank"}
	}
	if state.Flatpak && state.FlatpakZen {
		return Command{Name: "flatpak", Args: append([]string{"run", "app.zen_browser.zen"}, args...)}, true
	}
	if state.ZenBrowser {
		return Command{Name: "zen-browser", Args: args}, true
	}
	if state.Zen {
		return Command{Name: "zen", Args: args}, true
	}
	return Command{}, false
}

func isZenClass(class string) bool {
	return class == "app.zen_browser.zen" || class == "zen-browser"
}
