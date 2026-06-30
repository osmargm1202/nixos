package calendar

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/osmargm1202/nixos/internal/cli"
)

const SchemaVersion = 1

var Horizons = []int{1440, 720, 240, 60}

type Cache struct {
	SchemaVersion int     `json:"schemaVersion"`
	GeneratedAt   string  `json:"generatedAt"`
	LastSuccessAt string  `json:"lastSuccessAt"`
	Timezone      string  `json:"timezone"`
	Source        Source  `json:"source"`
	Status        Status  `json:"status"`
	Events        []Event `json:"events"`
}

type Source struct {
	Backend    string `json:"backend"`
	Command    string `json:"command"`
	RangeStart any    `json:"rangeStart"`
	RangeEnd   any    `json:"rangeEnd"`
}

type Status struct {
	SchemaVersion         int    `json:"schemaVersion,omitempty"`
	UpdatedAt             string `json:"updatedAt,omitempty"`
	CachePath             string `json:"cachePath,omitempty"`
	State                 string `json:"state"`
	Stale                 bool   `json:"stale"`
	Message               string `json:"message"`
	LastErrorKind         any    `json:"lastErrorKind"`
	LastError             any    `json:"lastError"`
	LastErrorAt           any    `json:"lastErrorAt,omitempty"`
	NotificationErrorKind any    `json:"notificationErrorKind,omitempty"`
}

type Event struct {
	ID               string `json:"id"`
	StableKey        string `json:"stableKey"`
	CalendarID       string `json:"calendarId"`
	CalendarName     string `json:"calendarName"`
	Title            string `json:"title"`
	Description      string `json:"description"`
	Location         string `json:"location"`
	Start            string `json:"start"`
	End              string `json:"end"`
	StartDate        string `json:"startDate"`
	EndDate          string `json:"endDate"`
	AllDay           bool   `json:"allDay"`
	HTMLLink         string `json:"htmlLink"`
	Status           string `json:"status"`
	AttendeesCount   int    `json:"attendeesCount"`
	ReminderEligible bool   `json:"reminderEligible"`
}

type UIRequest struct {
	SchemaVersion int    `json:"schemaVersion"`
	Action        string `json:"action"`
	RequestedAt   string `json:"requestedAt"`
	Source        string `json:"source"`
}

type reminderState struct {
	SchemaVersion   int            `json:"schemaVersion"`
	UpdatedAt       string         `json:"updatedAt"`
	HorizonsMinutes []int          `json:"horizonsMinutes"`
	Sent            map[string]any `json:"sent"`
}

func Run(args []string, stdout, stderr io.Writer) error {
	if len(args) == 0 {
		return cli.UsageError("usage: orgm-hypr calendar [sync|daemon|status|toggle-ui|open-web|open-event|add]")
	}
	if stdout == nil {
		stdout = io.Discard
	}
	switch args[0] {
	case "sync":
		return syncOnce()
	case "daemon":
		return daemon()
	case "status":
		return printStatus(stdout)
	case "toggle-ui":
		return toggleUI()
	case "open-web":
		if len(args) > 2 {
			return cli.UsageError("usage: orgm-hypr calendar open-web [date]")
		}
		date := ""
		if len(args) == 2 {
			date = args[1]
		}
		return openURL(webURL(date))
	case "add":
		if len(args) > 2 {
			return cli.UsageError("usage: orgm-hypr calendar add [date]")
		}
		date := ""
		if len(args) == 2 {
			date = args[1]
		}
		return openURL(addURL(date))
	case "open-event":
		if len(args) != 2 {
			return cli.UsageError("usage: orgm-hypr calendar open-event EVENT_ID")
		}
		return openEvent(args[1])
	default:
		return cli.UsageError("usage: orgm-hypr calendar [sync|daemon|status|toggle-ui|open-web|open-event|add]")
	}
}

func now() time.Time {
	if raw := os.Getenv("ORGM_CALENDAR_NOW"); raw != "" {
		if t, err := parseTime(raw); err == nil {
			return t
		}
	}
	return time.Now().UTC()
}
func iso(t time.Time) string { return t.Format(time.RFC3339) }
func cacheDir() string       { return filepath.Join(xdg("XDG_CACHE_HOME", ".cache"), "orgm-calendar") }
func stateDir() string       { return filepath.Join(xdg("XDG_STATE_HOME", ".local/state"), "orgm-calendar") }
func cachePath() string      { return filepath.Join(cacheDir(), "events.json") }
func statusPath() string     { return filepath.Join(stateDir(), "status.json") }
func remindersPath() string  { return filepath.Join(stateDir(), "reminders.json") }
func uiRequestPath() string  { return filepath.Join(stateDir(), "ui-request.json") }
func xdg(env, rel string) string {
	if v := os.Getenv(env); v != "" {
		return v
	}
	return filepath.Join(os.Getenv("HOME"), rel)
}

func atomicWriteJSON(path string, payload any) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	data, err := json.MarshalIndent(payload, "", "  ")
	if err != nil {
		return err
	}
	tmp, err := os.CreateTemp(filepath.Dir(path), "."+filepath.Base(path)+".")
	if err != nil {
		return err
	}
	name := tmp.Name()
	defer os.Remove(name)
	if _, err = tmp.Write(append(data, '\n')); err != nil {
		_ = tmp.Close()
		return err
	}
	if err = tmp.Sync(); err != nil {
		_ = tmp.Close()
		return err
	}
	if err = tmp.Close(); err != nil {
		return err
	}
	return os.Rename(name, path)
}

func writeStatus(s Status) error {
	base := Status{SchemaVersion: SchemaVersion, UpdatedAt: iso(now()), CachePath: cachePath(), State: "ok", Stale: false, Message: "", LastErrorKind: nil, LastError: nil}
	if s.State != "" {
		base.State = s.State
	}
	if s.Message != "" {
		base.Message = s.Message
	}
	base.Stale = s.Stale
	if s.LastErrorKind != nil {
		base.LastErrorKind = s.LastErrorKind
	}
	if s.LastError != nil {
		base.LastError = s.LastError
	}
	if s.NotificationErrorKind != nil {
		base.NotificationErrorKind = s.NotificationErrorKind
	}
	return atomicWriteJSON(statusPath(), base)
}

func gcalcliCommand() ([]string, bool) {
	if ov := os.Getenv("ORGM_CALENDAR_GCALCLI_CMD"); ov != "" {
		return []string{"sh", "-lc", ov}, true
	}
	p, err := exec.LookPath("gcalcli")
	if err != nil {
		return nil, false
	}
	return []string{p, "--nocolor", "agenda", "--tsv", "--details", "calendar", "--details", "url"}, true
}
func commandString(cmd []string) string { return strings.Join(cmd, " ") }
func runGcalcli() (string, []string, error) {
	cmdArgs, ok := gcalcliCommand()
	if !ok {
		return "", nil, classifiedError{"dependency_error", "gcalcli is required but was not found in PATH"}
	}
	cmd := exec.Command(cmdArgs[0], cmdArgs[1:]...)
	out, err := cmd.CombinedOutput()
	text := strings.TrimSpace(string(out))
	if err != nil {
		return "", cmdArgs, classifiedError{classifyError(text), text}
	}
	return text, cmdArgs, nil
}

type classifiedError struct{ kind, msg string }

func (e classifiedError) Error() string { return e.kind + ":" + e.msg }
func classifyError(text string) string {
	l := strings.ToLower(text)
	for _, w := range []string{"auth", "oauth", "token", "invalid_grant", "permission", "credential"} {
		if strings.Contains(l, w) {
			return "auth_error"
		}
	}
	for _, w := range []string{"network", "timeout", "timed out", "unreachable", "connection", "dns"} {
		if strings.Contains(l, w) {
			return "network_error"
		}
	}
	return "parse_error"
}

func syncOnce() error {
	out, cmd, err := runGcalcli()
	if err != nil {
		return failure(err)
	}
	events, err := ParseEvents(out)
	if err != nil {
		return failure(err)
	}
	state := "ok"
	if len(events) == 0 {
		state = "empty"
	}
	payload := Cache{SchemaVersion: SchemaVersion, GeneratedAt: iso(now()), LastSuccessAt: iso(now()), Timezone: time.Local.String(), Source: Source{Backend: "gcalcli", Command: commandString(cmd), RangeStart: nil, RangeEnd: nil}, Status: Status{State: state, Stale: false, Message: "", LastErrorAt: nil, LastErrorKind: nil, LastError: nil}, Events: events}
	if err := atomicWriteJSON(cachePath(), payload); err != nil {
		return failure(classifiedError{"unknown_error", err.Error()})
	}
	_ = writeStatus(Status{State: state})
	evaluateReminders(events)
	return nil
}
func failure(err error) error {
	kind, msg := "unknown_error", err.Error()
	var ce classifiedError
	if errors.As(err, &ce) {
		kind, msg = ce.kind, ce.msg
	}
	_ = writeStatus(Status{State: kind, Stale: fileExists(cachePath()), Message: msg, LastErrorKind: kind, LastError: msg})
	return &cli.ExitError{Code: 2, Err: fmt.Errorf("%s:%s", kind, msg)}
}
func fileExists(path string) bool { _, err := os.Stat(path); return err == nil }

func ParseEvents(output string) ([]Event, error) {
	if strings.TrimSpace(output) == "" {
		return nil, nil
	}
	var raws []map[string]any
	if err := json.Unmarshal([]byte(output), &raws); err == nil {
		return normalizeEvents(raws)
	}
	if strings.Contains(output, "\t") {
		return parseTSV(output)
	}
	return nil, classifiedError{classifyError(output), output}
}
func parseTSV(output string) ([]Event, error) {
	raws := []map[string]any{}
	for _, line := range strings.Split(output, "\n") {
		if strings.TrimSpace(line) == "" {
			continue
		}
		parts := strings.Split(line, "\t")
		if len(parts) < 3 {
			return nil, classifiedError{"parse_error", "expected tab-separated start/end/title fields: " + line}
		}
		raw := map[string]any{"start": parts[0], "end": parts[1], "title": parts[2]}
		if len(parts) > 3 {
			raw["calendarName"] = parts[3]
		}
		if len(parts) > 4 {
			raw["htmlLink"] = parts[4]
		}
		raws = append(raws, raw)
	}
	return normalizeEvents(raws)
}
func normalizeEvents(raws []map[string]any) ([]Event, error) {
	events := make([]Event, 0, len(raws))
	for _, raw := range raws {
		ev, err := normalizeEvent(raw)
		if err != nil {
			return nil, err
		}
		events = append(events, ev)
	}
	return events, nil
}
func normalizeEvent(raw map[string]any) (Event, error) {
	title := first(raw, "title", "summary")
	if title == "" {
		title = "Untitled event"
	}
	startRaw := first(raw, "start", "startTime", "date")
	endRaw := first(raw, "end", "endTime")
	if endRaw == "" {
		endRaw = startRaw
	}
	start, err := parseTime(startRaw)
	if err != nil {
		return Event{}, classifiedError{"parse_error", err.Error()}
	}
	end, err := parseTime(endRaw)
	if err != nil {
		return Event{}, classifiedError{"parse_error", err.Error()}
	}
	allDay := boolValue(raw["allDay"]) || len(startRaw) == 10
	id := first(raw, "id", "eventId")
	calendarID := first(raw, "calendarId")
	if calendarID == "" {
		calendarID = "primary"
	}
	stable := first(raw, "stableKey")
	if stable == "" {
		stable = id
	}
	if stable == "" {
		stable = calendarID + ":" + title + ":" + iso(start) + ":" + iso(end)
	}
	status := first(raw, "status")
	if status == "" {
		status = "confirmed"
	}
	eligible := true
	if v, ok := raw["reminderEligible"]; ok {
		eligible = boolValue(v)
	}
	if id == "" {
		id = stable
	}
	return Event{ID: id, StableKey: stable, CalendarID: calendarID, CalendarName: first(raw, "calendarName", "calendar"), Title: title, Description: first(raw, "description"), Location: first(raw, "location"), Start: iso(start), End: iso(end), StartDate: start.Format("2006-01-02"), EndDate: end.Format("2006-01-02"), AllDay: allDay, HTMLLink: first(raw, "htmlLink", "link"), Status: status, AttendeesCount: intValue(raw["attendeesCount"]), ReminderEligible: eligible}, nil
}
func first(raw map[string]any, keys ...string) string {
	for _, k := range keys {
		if v, ok := raw[k]; ok && fmt.Sprint(v) != "" {
			return fmt.Sprint(v)
		}
	}
	return ""
}
func boolValue(v any) bool {
	switch x := v.(type) {
	case bool:
		return x
	case string:
		return x == "true" || x == "1"
	default:
		return false
	}
}
func intValue(v any) int {
	switch x := v.(type) {
	case float64:
		return int(x)
	case int:
		return x
	case string:
		n, _ := strconv.Atoi(x)
		return n
	default:
		return 0
	}
}
func parseTime(raw string) (time.Time, error) {
	if raw == "" {
		return time.Time{}, fmt.Errorf("missing time")
	}
	if len(raw) == 10 {
		t, err := time.Parse("2006-01-02", raw)
		if err != nil {
			return t, err
		}
		return t.UTC(), nil
	}
	if t, err := time.Parse(time.RFC3339, strings.ReplaceAll(raw, "Z", "+00:00")); err == nil {
		return t, nil
	}
	return time.Parse("2006-01-02 15:04", raw)
}

func loadJSON(path string, out any) bool {
	data, err := os.ReadFile(path)
	if err != nil {
		return false
	}
	return json.Unmarshal(data, out) == nil
}
func evaluateReminders(events []Event) {
	cmd, ok := notifyCommand()
	if !ok {
		_ = writeStatus(Status{NotificationErrorKind: "dependency_error", Message: "notify-send is required for reminders"})
		return
	}
	st := reminderState{SchemaVersion: SchemaVersion, UpdatedAt: iso(now()), HorizonsMinutes: Horizons, Sent: map[string]any{}}
	_ = loadJSON(remindersPath(), &st)
	if st.Sent == nil {
		st.Sent = map[string]any{}
	}
	grace := 10
	if v := os.Getenv("ORGM_CALENDAR_REMINDER_GRACE_MINUTES"); v != "" {
		grace, _ = strconv.Atoi(v)
	}
	changed := false
	for _, ev := range events {
		if ev.AllDay || !ev.ReminderEligible {
			continue
		}
		start, _ := parseTime(ev.Start)
		mins := start.Sub(now()).Minutes()
		for _, h := range Horizons {
			key := fmt.Sprintf("%s|%d|%s", ev.StableKey, h, ev.Start)
			if _, ok := st.Sent[key]; ok {
				continue
			}
			if mins >= float64(h-grace) && mins <= float64(h) {
				c := exec.Command(cmd[0], append(cmd[1:], "Calendar: "+ev.Title, fmt.Sprintf("Starts in %s at %s", reminderText(h), start.Format("15:04")))...)
				if c.Run() == nil {
					st.Sent[key] = map[string]any{"eventStableKey": ev.StableKey, "horizonMinutes": h, "eventStart": ev.Start, "sentAt": iso(now()), "notifyExitCode": 0}
					changed = true
				}
			}
		}
	}
	if changed || fileExists(remindersPath()) == false {
		st.UpdatedAt = iso(now())
		_ = atomicWriteJSON(remindersPath(), st)
	}
}
func notifyCommand() ([]string, bool) {
	if ov := os.Getenv("ORGM_CALENDAR_NOTIFY_CMD"); ov != "" {
		return []string{"sh", "-lc", ov + " \"$@\"", "orgm-calendar-notify"}, true
	}
	p, err := exec.LookPath("notify-send")
	if err != nil {
		return nil, false
	}
	return []string{p}, true
}
func reminderText(m int) string {
	if m%60 == 0 {
		h := m / 60
		if h == 1 {
			return "1 hour"
		}
		return fmt.Sprintf("%d hours", h)
	}
	return fmt.Sprintf("%d minutes", m)
}

func openCommand() ([]string, bool) {
	if ov := os.Getenv("ORGM_CALENDAR_OPEN_CMD"); ov != "" {
		return []string{"sh", "-lc", ov + " \"$@\"", "orgm-calendar-open"}, true
	}
	p, err := exec.LookPath("xdg-open")
	if err != nil {
		return nil, false
	}
	return []string{p}, true
}
func openURL(u string) error {
	cmd, ok := openCommand()
	if !ok {
		_ = writeStatus(Status{State: "browser_error", Message: "xdg-open or ORGM_CALENDAR_OPEN_CMD is required"})
		return &cli.ExitError{Code: 2, Err: fmt.Errorf("browser opener required")}
	}
	c := exec.Command(cmd[0], append(cmd[1:], u)...)
	var b bytes.Buffer
	c.Stderr = &b
	if err := c.Run(); err != nil {
		_ = writeStatus(Status{State: "browser_error", Message: strings.TrimSpace(b.String())})
		return err
	}
	return nil
}
func webURL(date string) string {
	if date == "" {
		return "https://calendar.google.com/calendar/u/0/r"
	}
	t, _ := parseTime(date)
	return fmt.Sprintf("https://calendar.google.com/calendar/u/0/r/day/%d/%d/%d", t.Year(), t.Month(), t.Day())
}
func addURL(date string) string {
	base := "https://calendar.google.com/calendar/u/0/r/eventedit"
	if date == "" {
		return base
	}
	t, _ := parseTime(date)
	end := t.AddDate(0, 0, 1)
	return base + "?" + url.Values{"dates": []string{t.Format("20060102") + "/" + end.Format("20060102")}}.Encode()
}
func openEvent(id string) error {
	var cache Cache
	if !loadJSON(cachePath(), &cache) {
		_ = writeStatus(Status{State: "not_found", Message: "event not found: " + id})
		return &cli.ExitError{Code: 3, Err: fmt.Errorf("event not found: %s", id)}
	}
	for _, ev := range cache.Events {
		if ev.ID == id || ev.StableKey == id {
			u := ev.HTMLLink
			if u == "" {
				u = webURL(ev.StartDate)
			}
			return openURL(u)
		}
	}
	_ = writeStatus(Status{State: "not_found", Message: "event not found: " + id})
	return &cli.ExitError{Code: 3, Err: fmt.Errorf("event not found: %s", id)}
}
func printStatus(w io.Writer) error {
	var s Status
	if !loadJSON(statusPath(), &s) {
		s = Status{SchemaVersion: SchemaVersion, CachePath: cachePath(), State: "missing", Stale: fileExists(cachePath()), Message: "no status has been recorded yet"}
	}
	s.CachePath = cachePath()
	data, _ := json.MarshalIndent(s, "", "  ")
	fmt.Fprintln(w, string(data))
	return nil
}

func calendarUIRunning() bool {
	if ov := os.Getenv("ORGM_CALENDAR_UI_RUNNING"); ov != "" {
		return !strings.Contains("0 false False no", ov)
	}
	p, err := exec.LookPath("pgrep")
	if err != nil {
		return false
	}
	return exec.Command(p, "-f", `quickshell.*-c calendar`).Run() == nil
}
func startCalendarUI() error {
	cmd := []string{}
	if ov := os.Getenv("ORGM_CALENDAR_QUICKSHELL_CMD"); ov != "" {
		cmd = strings.Fields(ov)
	} else if p, err := exec.LookPath("quickshell"); err == nil {
		cmd = []string{p}
	}
	if len(cmd) == 0 {
		_ = writeStatus(Status{State: "ui_error", Message: "quickshell is required to open the calendar UI"})
		return &cli.ExitError{Code: 2, Err: fmt.Errorf("quickshell required")}
	}
	c := exec.Command(cmd[0], append(cmd[1:], "-c", "calendar")...)
	c.Env = append(os.Environ(), "ORGM_CALENDAR_SHOW=1")
	if os.Getenv("ORGM_CALENDAR_QUICKSHELL_CMD") != "" {
		return c.Run()
	}
	return c.Start()
}
func writeUIRequest(req UIRequest) error {
	path := uiRequestPath()
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	data, err := json.MarshalIndent(req, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, append(data, '\n'), 0o600)
}

func toggleUI() error {
	req := UIRequest{SchemaVersion: SchemaVersion, Action: "toggle", RequestedAt: iso(now()), Source: "orgm-hypr calendar toggle-ui"}
	if err := writeUIRequest(req); err != nil {
		return err
	}
	if calendarUIRunning() {
		return nil
	}
	return startCalendarUI()
}
func daemon() error {
	interval := 600
	if v := os.Getenv("ORGM_CALENDAR_SYNC_SECONDS"); v != "" {
		interval, _ = strconv.Atoi(v)
	}
	once := os.Getenv("ORGM_CALENDAR_DAEMON_ONCE") == "1"
	for {
		_ = syncOnce()
		if once {
			return nil
		}
		time.Sleep(time.Duration(interval) * time.Second)
	}
}
