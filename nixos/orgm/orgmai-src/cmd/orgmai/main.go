package main

import (
	"bufio"
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"syscall"
	"time"
)

const (
	defaultProvider = "openai-codex"
	defaultModel    = "gpt-5.6-luna"
	defaultThinking = "medium"
	systemPrompt    = "You are OrgM, a concise and helpful conversational assistant. Answer directly and clearly. This is a chat, not a coding-agent session."
)

var (
	errInterrupted = errors.New("interrupted")
	interrupts     = make(chan os.Signal, 1)
)

func init() {
	signal.Notify(interrupts, os.Interrupt, syscall.SIGTERM)
}

type config struct {
	Provider string `json:"provider"`
	Model    string `json:"model"`
	Thinking string `json:"thinking"`
}

type model struct {
	Provider  string `json:"provider"`
	ID        string `json:"id"`
	Name      string `json:"name"`
	Reasoning bool   `json:"reasoning"`
}

type app struct {
	configPath  string
	sessionsDir string
}

type appLock struct {
	file *os.File
}

type rpcClient struct {
	cmd       *exec.Cmd
	stdin     io.WriteCloser
	events    chan map[string]json.RawMessage
	done      chan struct{}
	writeMu   sync.Mutex
	stderrMu  sync.Mutex
	stderr    bytes.Buffer
	closeOnce sync.Once
}

func main() {
	defer signal.Stop(interrupts)
	application, err := newApp()
	if err != nil {
		fail(err)
	}
	args := os.Args[1:]
	if len(args) > 0 {
		switch args[0] {
		case "--help", "-h", "help":
			printHelp()
			return
		case "config":
			if err := application.configure(); err != nil {
				fail(err)
			}
			return
		}
	}
	lock, err := application.lock()
	if err != nil {
		fail(err)
	}
	defer lock.close()
	if len(args) == 0 {
		err = application.chat(nil, false)
	} else {
		switch args[0] {
		case "chat":
			err = application.chat(args[1:], false)
		case "new":
			err = application.chat(args[1:], true)
		case "prev":
			err = application.previous()
		default:
			err = application.chat(args, false)
		}
	}
	if err != nil {
		fail(err)
	}
}

func printHelp() {
	fmt.Print(`orgmai - persistent OrgM terminal chat backed by Pi

Usage:
  orgmai                    Resume the latest OrgM conversation
  orgmai chat [question]    Resume chat, or send one question and exit
  orgmai new [question]     Start a fresh OrgM conversation
  orgmai prev               Select an earlier OrgM conversation
  orgmai config             Choose Pi model and reasoning with Gum
  orgmai --help             Show this help

Configuration is stored privately at $XDG_CONFIG_HOME/orgmai/config.json.
Sessions are stored at $XDG_STATE_HOME/orgmai/sessions. Pi owns credentials.
`)
}

func newApp() (*app, error) {
	configHome := os.Getenv("XDG_CONFIG_HOME")
	if configHome == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return nil, fmt.Errorf("resolve home directory: %w", err)
		}
		configHome = filepath.Join(home, ".config")
	}
	stateHome := os.Getenv("XDG_STATE_HOME")
	if stateHome == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return nil, fmt.Errorf("resolve home directory: %w", err)
		}
		stateHome = filepath.Join(home, ".local", "state")
	}
	return &app{
		configPath:  filepath.Join(configHome, "orgmai", "config.json"),
		sessionsDir: filepath.Join(stateHome, "orgmai", "sessions"),
	}, nil
}

func (a *app) lock() (*appLock, error) {
	if err := os.MkdirAll(a.sessionsDir, 0700); err != nil {
		return nil, fmt.Errorf("create OrgM session directory: %w", err)
	}
	file, err := os.OpenFile(filepath.Join(a.sessionsDir, ".orgmai.lock"), os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		return nil, fmt.Errorf("open OrgM session lock: %w", err)
	}
	if err := syscall.Flock(int(file.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		file.Close()
		if errors.Is(err, syscall.EWOULDBLOCK) || errors.Is(err, syscall.EAGAIN) {
			return nil, errors.New("another OrgM chat is already running; close it before starting another")
		}
		return nil, fmt.Errorf("lock OrgM session directory: %w", err)
	}
	return &appLock{file: file}, nil
}

func (l *appLock) close() {
	_ = syscall.Flock(int(l.file.Fd()), syscall.LOCK_UN)
	_ = l.file.Close()
}

func (a *app) loadConfig() (config, error) {
	cfg := config{Provider: defaultProvider, Model: defaultModel, Thinking: defaultThinking}
	data, err := os.ReadFile(a.configPath)
	if errors.Is(err, os.ErrNotExist) {
		return cfg, nil
	}
	if err != nil {
		return config{}, fmt.Errorf("read OrgM configuration: %w", err)
	}
	if err := json.Unmarshal(data, &cfg); err != nil {
		return config{}, fmt.Errorf("parse OrgM configuration %s: %w", a.configPath, err)
	}
	if cfg.Provider == "" {
		cfg.Provider = defaultProvider
	}
	if cfg.Model == "" {
		cfg.Model = defaultModel
	}
	if cfg.Thinking == "" {
		cfg.Thinking = defaultThinking
	}
	return cfg, nil
}

func (a *app) saveConfig(cfg config) error {
	dir := filepath.Dir(a.configPath)
	if err := os.MkdirAll(dir, 0700); err != nil {
		return fmt.Errorf("create OrgM configuration directory: %w", err)
	}
	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return fmt.Errorf("encode OrgM configuration: %w", err)
	}
	data = append(data, '\n')
	tmp, err := os.CreateTemp(dir, ".config-*.json")
	if err != nil {
		return fmt.Errorf("create temporary OrgM configuration: %w", err)
	}
	tmpName := tmp.Name()
	defer os.Remove(tmpName)
	if err := tmp.Chmod(0600); err != nil {
		tmp.Close()
		return fmt.Errorf("protect temporary OrgM configuration: %w", err)
	}
	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		return fmt.Errorf("write temporary OrgM configuration: %w", err)
	}
	if err := tmp.Sync(); err != nil {
		tmp.Close()
		return fmt.Errorf("sync temporary OrgM configuration: %w", err)
	}
	if err := tmp.Close(); err != nil {
		return fmt.Errorf("close temporary OrgM configuration: %w", err)
	}
	if err := os.Rename(tmpName, a.configPath); err != nil {
		return fmt.Errorf("replace OrgM configuration: %w", err)
	}
	return os.Chmod(a.configPath, 0600)
}

func (a *app) configure() error {
	cfg, err := a.loadConfig()
	if err != nil {
		return err
	}
	client, err := startPi("", config{})
	if err != nil {
		return err
	}
	defer client.close()
	models, err := client.availableModels()
	if errors.Is(err, errInterrupted) {
		return nil
	}
	if err != nil {
		return err
	}
	if len(models) == 0 {
		return errors.New("Pi reported no available models")
	}
	sort.SliceStable(models, func(i, j int) bool {
		iCurrent := models[i].Provider == cfg.Provider && models[i].ID == cfg.Model
		jCurrent := models[j].Provider == cfg.Provider && models[j].ID == cfg.Model
		if iCurrent != jCurrent {
			return iCurrent
		}
		aFast := fastModel(models[i])
		bFast := fastModel(models[j])
		if aFast != bFast {
			return aFast
		}
		return modelKey(models[i]) < modelKey(models[j])
	})
	choices := make([]string, len(models))
	byChoice := make(map[string]model, len(models))
	for i, item := range models {
		label := modelKey(item)
		if item.Name != "" {
			label += " — " + item.Name
		}
		if item.Provider == cfg.Provider && item.ID == cfg.Model {
			label += " (current)"
		}
		choices[i] = label
		byChoice[label] = item
	}
	selected, cancelled, err := gumChoose("Choose a Pi model", choices)
	if err != nil {
		return err
	}
	if cancelled {
		return nil
	}
	selectedModel := byChoice[selected]
	levels := preferFirst(thinkingLevels(selectedModel), cfg.Thinking)
	thinking, cancelled, err := gumChoose("Choose reasoning level", levels)
	if err != nil {
		return err
	}
	if cancelled {
		return nil
	}
	cfg.Provider = selectedModel.Provider
	cfg.Model = selectedModel.ID
	cfg.Thinking = thinking
	if err := a.saveConfig(cfg); err != nil {
		return err
	}
	fmt.Printf("Saved %s with %s reasoning.\n", modelKey(selectedModel), thinking)
	return nil
}

func (a *app) chat(question []string, fresh bool) error {
	cfg, err := a.loadConfig()
	if err != nil {
		return err
	}
	session, err := a.sessionPath(fresh)
	if err != nil {
		return err
	}
	client, err := startPi(session, cfg)
	if err != nil {
		return err
	}
	defer client.close()
	if len(question) > 0 {
		prompt := strings.Join(question, " ")
		fmt.Printf("You> %s\n", prompt)
		err := client.prompt(prompt)
		if errors.Is(err, errInterrupted) {
			return nil
		}
		return err
	}
	fmt.Printf("OrgM chat · %s/%s · %s reasoning\n", cfg.Provider, cfg.Model, cfg.Thinking)
	fmt.Println("Press Ctrl+C or submit an empty prompt to close.")
	for {
		prompt, cancelled, err := gumInput()
		if err != nil {
			return err
		}
		if cancelled || strings.TrimSpace(prompt) == "" {
			return nil
		}
		fmt.Printf("You> %s\n", prompt)
		if err := client.prompt(prompt); err != nil {
			if errors.Is(err, errInterrupted) {
				return nil
			}
			fmt.Fprintf(os.Stderr, "OrgM error: %v\n", err)
		}
	}
}

func (a *app) previous() error {
	sessions, err := a.sessions()
	if err != nil {
		return err
	}
	if len(sessions) == 0 {
		return errors.New("no earlier OrgM conversations exist yet")
	}
	labels := make([]string, len(sessions))
	byLabel := make(map[string]string, len(sessions))
	for i, session := range sessions {
		info, err := os.Stat(session)
		if err != nil {
			return err
		}
		label := fmt.Sprintf("%s  %s  [%s]", info.ModTime().Local().Format("2006-01-02 15:04"), sessionPreview(session), strings.TrimSuffix(filepath.Base(session), ".jsonl"))
		labels[i] = label
		byLabel[label] = session
	}
	selected, cancelled, err := gumChoose("Resume an OrgM conversation", labels)
	if err != nil {
		return err
	}
	if cancelled {
		return nil
	}
	return a.chatSession(byLabel[selected])
}

func (a *app) chatSession(session string) error {
	cfg, err := a.loadConfig()
	if err != nil {
		return err
	}
	client, err := startPi(session, cfg)
	if err != nil {
		return err
	}
	defer client.close()
	fmt.Printf("OrgM chat · %s/%s · %s reasoning\n", cfg.Provider, cfg.Model, cfg.Thinking)
	for {
		prompt, cancelled, err := gumInput()
		if err != nil {
			return err
		}
		if cancelled || strings.TrimSpace(prompt) == "" {
			return nil
		}
		fmt.Printf("You> %s\n", prompt)
		if err := client.prompt(prompt); err != nil {
			if errors.Is(err, errInterrupted) {
				return nil
			}
			fmt.Fprintf(os.Stderr, "OrgM error: %v\n", err)
		}
	}
}

func (a *app) sessionPath(fresh bool) (string, error) {
	if !fresh {
		sessions, err := a.sessions()
		if err != nil {
			return "", err
		}
		if len(sessions) > 0 {
			return sessions[0], nil
		}
	}
	id, err := randomID()
	if err != nil {
		return "", err
	}
	return filepath.Join(a.sessionsDir, "orgm-"+id+".jsonl"), nil
}

func (a *app) sessions() ([]string, error) {
	if err := os.MkdirAll(a.sessionsDir, 0700); err != nil {
		return nil, fmt.Errorf("create OrgM session directory: %w", err)
	}
	entries, err := os.ReadDir(a.sessionsDir)
	if err != nil {
		return nil, fmt.Errorf("list OrgM conversations: %w", err)
	}
	type candidate struct {
		path     string
		modified time.Time
	}
	var candidates []candidate
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".jsonl") {
			continue
		}
		info, err := entry.Info()
		if err != nil {
			return nil, fmt.Errorf("read OrgM conversation %s: %w", entry.Name(), err)
		}
		candidates = append(candidates, candidate{filepath.Join(a.sessionsDir, entry.Name()), info.ModTime()})
	}
	sort.Slice(candidates, func(i, j int) bool { return candidates[i].modified.After(candidates[j].modified) })
	result := make([]string, len(candidates))
	for i := range candidates {
		result[i] = candidates[i].path
	}
	return result, nil
}

func sessionPreview(path string) string {
	file, err := os.Open(path)
	if err != nil {
		return "Conversation"
	}
	defer file.Close()
	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 4096), 8*1024*1024)
	for scanner.Scan() {
		var entry struct {
			Type    string `json:"type"`
			Message struct {
				Role    string          `json:"role"`
				Content json.RawMessage `json:"content"`
			} `json:"message"`
		}
		if json.Unmarshal(scanner.Bytes(), &entry) != nil || entry.Type != "message" || entry.Message.Role != "user" {
			continue
		}
		var text string
		if json.Unmarshal(entry.Message.Content, &text) != nil {
			var blocks []struct {
				Type string `json:"type"`
				Text string `json:"text"`
			}
			if json.Unmarshal(entry.Message.Content, &blocks) != nil {
				continue
			}
			var parts []string
			for _, block := range blocks {
				if block.Type == "text" {
					parts = append(parts, block.Text)
				}
			}
			text = strings.Join(parts, " ")
		}
		text = strings.Join(strings.Fields(text), " ")
		if text == "" {
			continue
		}
		runes := 0
		for index := range text {
			if runes == 64 {
				return text[:index] + "…"
			}
			runes++
		}
		return text
	}
	return "Conversation"
}

func randomID() (string, error) {
	bytes := make([]byte, 16)
	if _, err := rand.Read(bytes); err != nil {
		return "", fmt.Errorf("generate conversation ID: %w", err)
	}
	return hex.EncodeToString(bytes), nil
}

func startPi(session string, cfg config) (*rpcClient, error) {
	args := []string{"--mode", "rpc", "--offline", "--no-tools", "--no-extensions", "--no-skills", "--no-prompt-templates", "--no-themes", "--no-context-files"}
	if session == "" {
		args = append(args, "--no-session")
	} else {
		args = append(args, "--session", session, "--provider", cfg.Provider, "--model", cfg.Model, "--thinking", cfg.Thinking, "--system-prompt", systemPrompt)
	}
	pi, err := findPi()
	if err != nil {
		return nil, err
	}
	cmd := exec.Command(pi, args...)
	// A managed Pi script may use /usr/bin/env node. Keep its own runtime
	// directory available even when the desktop did not initialize FNM.
	cmd.Env = append(withoutPackageDir(os.Environ()), "PATH="+filepath.Dir(pi)+string(os.PathListSeparator)+os.Getenv("PATH"))
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return nil, fmt.Errorf("open Pi input: %w", err)
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, fmt.Errorf("open Pi output: %w", err)
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return nil, fmt.Errorf("open Pi errors: %w", err)
	}
	client := &rpcClient{cmd: cmd, stdin: stdin, events: make(chan map[string]json.RawMessage, 64), done: make(chan struct{})}
	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("start Pi: %w", err)
	}
	go client.readEvents(stdout)
	go client.readStderr(stderr)
	go func() { _ = cmd.Wait(); close(client.done) }()
	return client, nil
}

func findPi() (string, error) {
	if path, err := exec.LookPath("pi"); err == nil {
		return path, nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", fmt.Errorf("locate native Pi: %w", err)
	}
	bunHome := os.Getenv("BUN_INSTALL")
	if bunHome == "" {
		bunHome = filepath.Join(home, ".bun")
	}
	npmPrefix := os.Getenv("NPM_CONFIG_PREFIX")
	if npmPrefix == "" {
		npmPrefix = filepath.Join(home, ".npm-global")
	}
	fnmHome := os.Getenv("FNM_DIR")
	if fnmHome == "" {
		dataHome := os.Getenv("XDG_DATA_HOME")
		if dataHome == "" {
			dataHome = filepath.Join(home, ".local", "share")
		}
		fnmHome = filepath.Join(dataHome, "fnm")
	}
	for _, directory := range []string{
		filepath.Join(home, ".local", "bin"),
		filepath.Join(bunHome, "bin"),
		filepath.Join(npmPrefix, "bin"),
		filepath.Join(fnmHome, "aliases", "default", "bin"),
	} {
		if path, err := exec.LookPath(filepath.Join(directory, "pi")); err == nil {
			return path, nil
		}
	}
	return "", errors.New("native Pi was not found; run pi-install or add pi to PATH")
}

func withoutPackageDir(environment []string) []string {
	result := make([]string, 0, len(environment))
	for _, item := range environment {
		if !strings.HasPrefix(item, "PI_PACKAGE_DIR=") {
			result = append(result, item)
		}
	}
	return result
}

func (c *rpcClient) readEvents(reader io.Reader) {
	scanner := bufio.NewScanner(reader)
	scanner.Buffer(make([]byte, 64*1024), 8*1024*1024)
	for scanner.Scan() {
		var event map[string]json.RawMessage
		if err := json.Unmarshal(scanner.Bytes(), &event); err == nil {
			c.events <- event
		} else {
			c.appendStderr("Pi emitted invalid RPC JSON: " + err.Error())
		}
	}
	if err := scanner.Err(); err != nil {
		c.appendStderr("Pi RPC output: " + err.Error())
	}
	close(c.events)
}

func (c *rpcClient) readStderr(reader io.Reader) {
	data, _ := io.ReadAll(reader)
	if len(data) > 0 {
		c.appendStderr(strings.TrimSpace(string(data)))
	}
}

func (c *rpcClient) appendStderr(message string) {
	if message == "" {
		return
	}
	c.stderrMu.Lock()
	defer c.stderrMu.Unlock()
	if c.stderr.Len() > 0 {
		c.stderr.WriteByte('\n')
	}
	c.stderr.WriteString(message)
}

func (c *rpcClient) errorWithStderr(prefix string) error {
	c.stderrMu.Lock()
	defer c.stderrMu.Unlock()
	if c.stderr.Len() == 0 {
		return errors.New(prefix)
	}
	return fmt.Errorf("%s: %s", prefix, c.stderr.String())
}

func (c *rpcClient) send(command any) error {
	data, err := json.Marshal(command)
	if err != nil {
		return err
	}
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	select {
	case <-c.done:
		return c.errorWithStderr("Pi stopped")
	default:
	}
	_, err = c.stdin.Write(append(data, '\n'))
	if err != nil {
		return c.errorWithStderr("write to Pi")
	}
	return nil
}

func (c *rpcClient) availableModels() ([]model, error) {
	if err := c.send(map[string]any{"id": "models", "type": "get_available_models"}); err != nil {
		return nil, err
	}
	for {
		select {
		case event, ok := <-c.events:
			if !ok {
				return nil, c.errorWithStderr("Pi closed before returning its model catalog")
			}
			if stringField(event, "type") != "response" || stringField(event, "id") != "models" {
				continue
			}
			if !boolField(event, "success") {
				return nil, errors.New(errorMessage(event))
			}
			var data struct {
				Models []model `json:"models"`
			}
			if err := json.Unmarshal(event["data"], &data); err != nil {
				return nil, fmt.Errorf("parse Pi model catalog: %w", err)
			}
			return data.Models, nil
		case <-c.done:
			return nil, c.errorWithStderr("Pi stopped before returning its model catalog")
		case <-interrupts:
			return nil, errInterrupted
		}
	}
}

func (c *rpcClient) prompt(message string) error {
	const promptID = "prompt"
	if err := c.send(map[string]any{"id": promptID, "type": "prompt", "message": message}); err != nil {
		return err
	}
	var answer strings.Builder
	var ticks <-chan time.Time
	interactive := false
	if info, err := os.Stderr.Stat(); err == nil {
		interactive = info.Mode()&os.ModeCharDevice != 0 && os.Getenv("TERM") != "dumb"
	}
	waiting := true
	frame := 0
	drawWaiting := func() {
		fmt.Fprintf(os.Stderr, "\r\x1b[2K%c OrgM: thinking...", "|/-\\"[frame%4])
		frame++
	}
	stopWaiting := func() {
		if waiting && interactive {
			fmt.Fprint(os.Stderr, "\r\x1b[2K\x1b[?25h")
		}
		waiting = false
	}
	if interactive {
		ticker := time.NewTicker(100 * time.Millisecond)
		defer ticker.Stop()
		ticks = ticker.C
		fmt.Fprint(os.Stderr, "\x1b[?25l")
		drawWaiting()
	}
	defer stopWaiting()
	started := false
	legacyProtocol := false
	legacyStateNumber := 0
	legacyStateID := ""
	lastAssistantError := ""
	finish := func() error {
		stopWaiting()
		if lastAssistantError != "" {
			return errors.New(lastAssistantError)
		}
		fmt.Printf("OrgM> %s\n", answer.String())
		return nil
	}
	requestLegacyState := func() (string, error) {
		legacyStateNumber++
		id := fmt.Sprintf("legacy-state-%d", legacyStateNumber)
		if err := c.send(map[string]any{"id": id, "type": "get_state"}); err != nil {
			return "", err
		}
		return id, nil
	}
	for {
		select {
		case event, ok := <-c.events:
			if !ok {
				if lastAssistantError != "" {
					return errors.New(lastAssistantError)
				}
				return c.errorWithStderr("Pi closed before the response settled")
			}
			eventType := stringField(event, "type")
			if eventType == "response" {
				responseID := stringField(event, "id")
				if responseID == promptID {
					if !boolField(event, "success") {
						return errors.New(errorMessage(event))
					}
					started = true
					continue
				}
				if responseID == legacyStateID {
					legacyStateID = ""
					if !boolField(event, "success") {
						return errors.New(errorMessage(event))
					}
					var state struct {
						IsStreaming         bool `json:"isStreaming"`
						IsCompacting        bool `json:"isCompacting"`
						PendingMessageCount int  `json:"pendingMessageCount"`
					}
					if err := json.Unmarshal(event["data"], &state); err != nil {
						return fmt.Errorf("parse Pi completion state: %w", err)
					}
					if started && !state.IsStreaming && !state.IsCompacting && state.PendingMessageCount == 0 {
						return finish()
					}
					continue
				}
			}
			if eventType == "message_start" {
				lastAssistantError = ""
				answer.Reset()
			}
			if messageError := assistantMessageError(event); messageError != "" {
				lastAssistantError = messageError
			}
			if eventType == "error" || eventType == "agent_error" {
				lastAssistantError = errorMessage(event)
			}
			if text := textDelta(event); text != "" {
				answer.WriteString(text)
			}
			if eventType == "agent_settled" && started {
				return finish()
			}
			if eventType == "agent_end" && !boolField(event, "willRetry") {
				legacyProtocol = true
				id, err := requestLegacyState()
				if err != nil {
					return err
				}
				legacyStateID = id
			}
			if (eventType == "auto_compaction_end" || eventType == "compaction_end") && legacyProtocol && legacyStateID == "" {
				id, err := requestLegacyState()
				if err != nil {
					return err
				}
				legacyStateID = id
			}
		case <-ticks:
			if interactive {
				drawWaiting()
			}
		case <-c.done:
			if lastAssistantError != "" {
				return errors.New(lastAssistantError)
			}
			return c.errorWithStderr("Pi stopped before the response settled")
		case <-interrupts:
			_ = c.send(map[string]string{"type": "abort"})
			return errInterrupted
		}
	}
}

func (c *rpcClient) close() {
	c.closeOnce.Do(func() {
		_ = c.send(map[string]string{"type": "abort"})
		_ = c.stdin.Close()
		select {
		case <-c.done:
		case <-time.After(2 * time.Second):
			_ = c.cmd.Process.Kill()
			<-c.done
		}
	})
}

func textDelta(event map[string]json.RawMessage) string {
	if stringField(event, "type") == "text_delta" {
		return stringField(event, "delta")
	}
	if stringField(event, "type") != "message_update" {
		return ""
	}
	var update struct {
		AssistantMessageEvent struct {
			Type  string `json:"type"`
			Delta string `json:"delta"`
		} `json:"assistantMessageEvent"`
	}
	if err := json.Unmarshal(event["assistantMessageEvent"], &update.AssistantMessageEvent); err != nil {
		return ""
	}
	if update.AssistantMessageEvent.Type == "text_delta" {
		return update.AssistantMessageEvent.Delta
	}
	return ""
}

func assistantMessageError(event map[string]json.RawMessage) string {
	if stringField(event, "type") != "message_end" {
		return ""
	}
	var message struct {
		Role         string `json:"role"`
		StopReason   string `json:"stopReason"`
		ErrorMessage string `json:"errorMessage"`
	}
	if err := json.Unmarshal(event["message"], &message); err != nil {
		return ""
	}
	if message.Role != "assistant" || message.StopReason != "error" {
		return ""
	}
	if message.ErrorMessage != "" {
		return readableError(message.ErrorMessage)
	}
	return "Pi assistant response failed"
}
func errorMessage(event map[string]json.RawMessage) string {
	if message := rawField(event, "error"); message != "" && message != "null" {
		return readableError(message)
	}
	if message := rawField(event, "message"); message != "" && message != "null" {
		return readableError(message)
	}
	return "Pi reported an unknown error"
}

func readableError(message string) string {
	var details map[string]json.RawMessage
	if json.Unmarshal([]byte(message), &details) != nil {
		return message
	}
	for _, key := range []string{"message", "detail", "error", "error_description"} {
		if value := rawField(details, key); value != "" && value != "null" {
			return readableError(value)
		}
	}
	return message
}

func rawField(event map[string]json.RawMessage, key string) string {
	raw := event[key]
	var value string
	if json.Unmarshal(raw, &value) == nil {
		return value
	}
	return string(raw)
}

func stringField(event map[string]json.RawMessage, key string) string {
	var value string
	_ = json.Unmarshal(event[key], &value)
	return value
}

func boolField(event map[string]json.RawMessage, key string) bool {
	var value bool
	_ = json.Unmarshal(event[key], &value)
	return value
}

func modelKey(item model) string { return item.Provider + "/" + item.ID }

func fastModel(item model) bool {
	value := strings.ToLower(modelKey(item) + " " + item.Name)
	return strings.Contains(value, "mini") || strings.Contains(value, "nano") || strings.Contains(value, "flash") || strings.Contains(value, "haiku") || strings.Contains(value, "small")
}

func thinkingLevels(item model) []string {
	supported := []string{"low", "minimal", "medium", "high", "xhigh", "off"}
	if !item.Reasoning {
		return []string{"off"}
	}
	return supported
}

func preferFirst(values []string, preferred string) []string {
	for i, value := range values {
		if value == preferred {
			return append([]string{value}, append(values[:i:i], values[i+1:]...)...)
		}
	}
	return values
}

func gumInput() (string, bool, error) {
	cmd := exec.Command("gum", "input", "--prompt", "You> ", "--placeholder", "Ask OrgM",
		"--no-show-help", "--header", "enter \x1b[38;2;138;173;244msubmit\x1b[0m · ctrl+c cancel")
	cmd.Stdin = os.Stdin
	cmd.Stderr = os.Stderr
	output, err := cmd.Output()
	if err != nil {
		if gumCancelled(err) {
			return "", true, nil
		}
		return "", false, fmt.Errorf("run gum input: %w", err)
	}
	return strings.TrimSpace(string(output)), false, nil
}

func gumChoose(header string, choices []string) (string, bool, error) {
	cmd := exec.Command("gum", "choose", "--header", header)
	cmd.Stdin = strings.NewReader(strings.Join(choices, "\n") + "\n")
	cmd.Stderr = os.Stderr
	output, err := cmd.Output()
	if err != nil {
		if gumCancelled(err) {
			return "", true, nil
		}
		return "", false, fmt.Errorf("run gum choose: %w", err)
	}
	return strings.TrimSpace(string(output)), false, nil
}

func gumCancelled(err error) bool {
	var exit *exec.ExitError
	return errors.As(err, &exit) && exit.ExitCode() == 130
}

func fail(err error) {
	fmt.Fprintln(os.Stderr, "orgmai:", err)
	os.Exit(1)
}
