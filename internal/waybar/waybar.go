package waybar

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

type WatchPlanData struct {
	Profile    string
	LogPath    string
	WaybarArgs []string
}

func FormatDate(t time.Time, format string) (string, error) {
	switch format {
	case "date-es":
		return t.Format("02/01/2006"), nil
	case "day-month-es":
		return spanishWeekday(t.Weekday()) + " - " + spanishMonth(t.Month()), nil
	case "time-ampm":
		return t.Format("3:04 PM"), nil
	default:
		return "", fmt.Errorf("unknown waybar date format %q", format)
	}
}

func SwapUsageFromMeminfo(r io.Reader) (string, error) {
	var total, free int
	scanner := bufio.NewScanner(r)
	for scanner.Scan() {
		fields := strings.Fields(scanner.Text())
		if len(fields) < 2 {
			continue
		}
		value, err := strconv.Atoi(fields[1])
		if err != nil {
			continue
		}
		switch fields[0] {
		case "SwapTotal:":
			total = value
		case "SwapFree:":
			free = value
		}
	}
	if err := scanner.Err(); err != nil {
		return "", err
	}
	if total <= 0 {
		return "󰓡 SWAP 0%", nil
	}
	used := total - free
	pct := int(float64(used*100)/float64(total) + 0.5)
	return fmt.Sprintf("󰓡 SWAP %d%%", pct), nil
}

func WorkspaceStatusJSON(workspaceID, activeWorkspaceID, windows int) (string, error) {
	class := []string{"workspace", "empty"}
	if windows > 0 {
		class = []string{"workspace", "occupied"}
	}
	if activeWorkspaceID == workspaceID {
		class = []string{"workspace", "active"}
	}
	payload := struct {
		Text    string   `json:"text"`
		Tooltip string   `json:"tooltip"`
		Class   []string `json:"class"`
	}{
		Text:    strconv.Itoa(workspaceID),
		Tooltip: fmt.Sprintf("Workspace %d · %d window(s)", workspaceID, windows),
		Class:   class,
	}
	data, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}
	return string(data) + "\n", nil
}

func WatchPlan(configDir, stateHome string) WatchPlanData {
	profile := filepath.Base(configDir)
	return WatchPlanData{
		Profile: profile,
		LogPath: filepath.Join(stateHome, "waybar", profile+".log"),
		WaybarArgs: []string{
			"-c", filepath.Join(configDir, "config"),
			"-s", filepath.Join(configDir, "style.css"),
		},
	}
}

func spanishWeekday(day time.Weekday) string {
	switch day {
	case time.Monday:
		return "Lunes"
	case time.Tuesday:
		return "Martes"
	case time.Wednesday:
		return "Miércoles"
	case time.Thursday:
		return "Jueves"
	case time.Friday:
		return "Viernes"
	case time.Saturday:
		return "Sábado"
	case time.Sunday:
		return "Domingo"
	default:
		return ""
	}
}

func spanishMonth(month time.Month) string {
	switch month {
	case time.January:
		return "Enero"
	case time.February:
		return "Febrero"
	case time.March:
		return "Marzo"
	case time.April:
		return "Abril"
	case time.May:
		return "Mayo"
	case time.June:
		return "Junio"
	case time.July:
		return "Julio"
	case time.August:
		return "Agosto"
	case time.September:
		return "Septiembre"
	case time.October:
		return "Octubre"
	case time.November:
		return "Noviembre"
	case time.December:
		return "Diciembre"
	default:
		return ""
	}
}
