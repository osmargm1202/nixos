package windows

import (
	"encoding/json"
	"fmt"
	"sort"
	"strings"
)

type Command struct {
	Name string
	Args []string
}

type ClientRow struct {
	Address string
	Label   string
}

type KillCandidate struct {
	PID   int
	RSSKB int
	Label string
}

type client struct {
	Address      string `json:"address"`
	Class        string `json:"class"`
	InitialClass string `json:"initialClass"`
	Title        string `json:"title"`
	PID          int    `json:"pid"`
	Workspace    struct {
		Name string `json:"name"`
	} `json:"workspace"`
}

func ClientRowsFromJSON(data []byte) ([]ClientRow, error) {
	var clients []client
	if err := json.Unmarshal(data, &clients); err != nil {
		return nil, err
	}
	rows := make([]ClientRow, 0, len(clients))
	for _, c := range clients {
		if strings.TrimSpace(c.Address) == "" {
			continue
		}
		rows = append(rows, ClientRow{Address: c.Address, Label: fmt.Sprintf("[%s] %s — %s", c.Workspace.Name, c.Class, c.Title)})
	}
	return rows, nil
}

func FocusCommand(address string) (Command, bool) {
	address = strings.TrimSpace(address)
	if address == "" {
		return Command{}, false
	}
	return Command{Name: "hyprctl", Args: []string{"dispatch", fmt.Sprintf(`hl.dsp.focus({ window = "address:%s" })`, address)}}, true
}

func KillCandidatesFromJSON(data []byte, minRSSKB int, rssOwner func(pid int) (rssKB int, owned bool)) ([]KillCandidate, error) {
	var clients []client
	if err := json.Unmarshal(data, &clients); err != nil {
		return nil, err
	}
	seen := map[int]bool{}
	candidates := []KillCandidate{}
	for _, c := range clients {
		if c.PID <= 0 || seen[c.PID] {
			continue
		}
		seen[c.PID] = true
		rssKB, owned := rssOwner(c.PID)
		if !owned || rssKB <= minRSSKB {
			continue
		}
		app := safeText(firstNonEmpty(c.Class, c.InitialClass, "unknown"))
		title := safeText(firstNonEmpty(c.Title, "untitled"))
		workspace := safeText(c.Workspace.Name)
		context := ""
		if workspace != "" {
			context = "[" + workspace + "] "
		}
		label := fmt.Sprintf("%7.1f MB  PID %-7d  %s%s — %s", float64(rssKB)/1024, c.PID, context, app, title)
		candidates = append(candidates, KillCandidate{PID: c.PID, RSSKB: rssKB, Label: label})
	}
	sort.SliceStable(candidates, func(i, j int) bool { return candidates[i].RSSKB > candidates[j].RSSKB })
	return candidates, nil
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if value != "" {
			return value
		}
	}
	return ""
}

func safeText(value string) string {
	return strings.NewReplacer("\t", " ", "\r", " ", "\n", " ").Replace(value)
}
