package main

import (
	"encoding/json"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

type discardInput struct{ io.Writer }

func (discardInput) Close() error { return nil }

func promptFixture(t *testing.T) (*rpcClient, <-chan error, func() string) {
	t.Helper()
	output, err := os.CreateTemp(t.TempDir(), "output")
	if err != nil {
		t.Fatal(err)
	}
	oldOut, oldErr := os.Stdout, os.Stderr
	os.Stdout, os.Stderr = output, output
	client := &rpcClient{
		stdin:  discardInput{io.Discard},
		events: make(chan map[string]json.RawMessage),
		done:   make(chan struct{}),
	}
	result := make(chan error, 1)
	finished := make(chan struct{})
	go func() {
		result <- client.prompt("hello")
		close(finished)
	}()
	t.Cleanup(func() {
		close(client.events)
		select {
		case <-finished:
		case <-time.After(3 * time.Second):
			t.Error("prompt did not exit after event stream closed")
		}
		os.Stdout, os.Stderr = oldOut, oldErr
		output.Close()
	})
	return client, result, func() string {
		t.Helper()
		data, err := os.ReadFile(output.Name())
		if err != nil {
			t.Fatal(err)
		}
		return string(data)
	}
}

func sendEvent(t *testing.T, client *rpcClient, text string) {
	t.Helper()
	var event map[string]json.RawMessage
	if err := json.Unmarshal([]byte(text), &event); err != nil {
		t.Fatal(err)
	}
	select {
	case client.events <- event:
	case <-time.After(3 * time.Second):
		t.Fatal("prompt stopped consuming events")
	}
}

func promptResult(t *testing.T, result <-chan error) error {
	t.Helper()
	select {
	case err := <-result:
		return err
	case <-time.After(3 * time.Second):
		t.Fatal("prompt did not finish")
		return nil
	}
}

func TestPromptWaitsUntilResponseSettles(t *testing.T) {
	client, result, output := promptFixture(t)
	sendEvent(t, client, `{"type":"response","id":"prompt","success":true}`)
	sendEvent(t, client, `{"type":"message_start"}`)
	sendEvent(t, client, `{"type":"text_delta","delta":"Hello"}`)
	sendEvent(t, client, `{"type":"message_update","assistantMessageEvent":{"type":"text_delta","delta":" world"}}`)
	// Consuming the next event proves both text deltas were processed.
	sendEvent(t, client, `{"type":"message_end"}`)
	if got := output(); got != "" {
		t.Fatalf("printed an unfinished response: %q", got)
	}
	sendEvent(t, client, `{"type":"agent_settled"}`)
	if err := promptResult(t, result); err != nil {
		t.Fatal(err)
	}
	if got := output(); got != "OrgM> Hello world\n" {
		t.Fatalf("completed response: %q", got)
	}
}

func TestFailedResponseDoesNotPrintPartialAnswer(t *testing.T) {
	client, result, output := promptFixture(t)
	sendEvent(t, client, `{"type":"response","id":"prompt","success":true}`)
	sendEvent(t, client, `{"type":"message_start"}`)
	sendEvent(t, client, `{"type":"text_delta","delta":"Incomplete answer"}`)
	sendEvent(t, client, `{"type":"message_end","message":{"role":"assistant","stopReason":"error","errorMessage":"{\"detail\":\"Model unavailable for this account\"}"}}`)
	sendEvent(t, client, `{"type":"agent_settled"}`)
	err := promptResult(t, result)
	if err == nil || err.Error() != "Model unavailable for this account" {
		t.Fatalf("provider error was not readable: %v", err)
	}
	if got := output(); got != "" {
		t.Fatalf("failed response leaked into chat: %q", got)
	}
}

func TestRetryReplacesFailedPartialAnswer(t *testing.T) {
	client, result, output := promptFixture(t)
	sendEvent(t, client, `{"type":"response","id":"prompt","success":true}`)
	sendEvent(t, client, `{"type":"message_start"}`)
	sendEvent(t, client, `{"type":"text_delta","delta":"Discard this attempt"}`)
	sendEvent(t, client, `{"type":"agent_error","error":{"message":"Temporarily unavailable"}}`)
	sendEvent(t, client, `{"type":"agent_end","willRetry":true}`)
	sendEvent(t, client, `{"type":"message_start"}`)
	sendEvent(t, client, `{"type":"text_delta","delta":"Recovered answer"}`)
	sendEvent(t, client, `{"type":"agent_settled"}`)
	if err := promptResult(t, result); err != nil {
		t.Fatal(err)
	}
	if got := output(); got != "OrgM> Recovered answer\n" {
		t.Fatalf("retry included failed output: %q", got)
	}
}

func TestRPCErrorUnwrapsNestedProviderMessage(t *testing.T) {
	client, result, output := promptFixture(t)
	sendEvent(t, client, `{"type":"response","id":"prompt","success":false,"error":{"error":{"message":"Authentication expired"}}}`)
	err := promptResult(t, result)
	if err == nil || err.Error() != "Authentication expired" {
		t.Fatalf("nested provider error was not readable: %v", err)
	}
	if got := output(); got != "" {
		t.Fatalf("error printed an assistant response: %q", got)
	}
}

func TestNewConversationAppearsFirstInHistory(t *testing.T) {
	a := &app{sessionsDir: t.TempDir()}
	oldPath := filepath.Join(a.sessionsDir, "older.jsonl")
	if err := os.WriteFile(oldPath, []byte("{\"type\":\"session\"}\n"), 0600); err != nil {
		t.Fatal(err)
	}
	oldTime := time.Unix(1000, 0)
	if err := os.Chtimes(oldPath, oldTime, oldTime); err != nil {
		t.Fatal(err)
	}
	if sessions, err := a.sessions(); err != nil || len(sessions) != 1 {
		t.Fatalf("initial history: %v, %v", sessions, err)
	}
	newPath, err := a.sessionPath(true)
	if err != nil {
		t.Fatal(err)
	}
	if newPath == oldPath {
		t.Fatal("new conversation reused the previous session")
	}
	data := "{\"type\":\"session\"}\n" +
		"{\"type\":\"message\",\"message\":{\"role\":\"user\",\"content\":[{\"type\":\"image\"},{\"type\":\"text\",\"text\":\"Nueva\\nconversación de hoy\"}]}}\n"
	if err := os.WriteFile(newPath, []byte(data), 0600); err != nil {
		t.Fatal(err)
	}
	newTime := oldTime.Add(time.Hour)
	if err := os.Chtimes(newPath, newTime, newTime); err != nil {
		t.Fatal(err)
	}
	sessions, err := a.sessions()
	if err != nil || len(sessions) != 2 || sessions[0] != newPath || sessions[1] != oldPath {
		t.Fatalf("new conversation missing from the top of history: %v, %v", sessions, err)
	}
	if got := sessionPreview(newPath); got != "Nueva conversación de hoy" {
		t.Fatalf("history preview: %q", got)
	}
	resumed, err := a.sessionPath(false)
	if err != nil || resumed != newPath {
		t.Fatalf("explicit resume did not select latest conversation: %q, %v", resumed, err)
	}
}

func isolatedNativeRuntime(t *testing.T) string {
	t.Helper()
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("PATH", filepath.Join(home, "empty-path"))
	t.Setenv("XDG_DATA_HOME", filepath.Join(home, "data"))
	t.Setenv("BUN_INSTALL", "")
	t.Setenv("NPM_CONFIG_PREFIX", "")
	t.Setenv("FNM_DIR", "")
	return home
}

func TestStartPiFindsFNMRuntimeWithoutShellInitialization(t *testing.T) {
	envPath, err := exec.LookPath("env")
	if err != nil {
		t.Fatal(err)
	}
	shPath, err := exec.LookPath("sh")
	if err != nil {
		t.Fatal(err)
	}
	home := isolatedNativeRuntime(t)
	bin := filepath.Join(home, "data", "fnm", "aliases", "default", "bin")
	if err := os.MkdirAll(bin, 0700); err != nil {
		t.Fatal(err)
	}
	// Like native Pi, this entrypoint requires its managed Node interpreter.
	if err := os.WriteFile(filepath.Join(bin, "pi"), []byte("#!"+envPath+" node\n"), 0700); err != nil {
		t.Fatal(err)
	}
	node := "#!" + shPath + "\n" + `
while IFS= read -r command; do
  case "$command" in
    *get_available_models*)
      printf '%s\n' '{"type":"response","id":"models","success":true,"data":{"models":[{"provider":"test","id":"native-runtime"}]}}'
      ;;
    *abort*) exit 0 ;;
  esac
done
`
	if err := os.WriteFile(filepath.Join(bin, "node"), []byte(node), 0700); err != nil {
		t.Fatal(err)
	}
	client, err := startPi("", config{})
	if err != nil {
		t.Fatal(err)
	}
	defer client.close()
	models, err := client.availableModels()
	if err != nil || len(models) != 1 || models[0].ID != "native-runtime" {
		t.Fatalf("Pi could not run with the managed interpreter: %v, %v", models, err)
	}
}

func TestMissingPiExplainsHowToInstall(t *testing.T) {
	isolatedNativeRuntime(t)
	client, err := startPi("", config{})
	if client != nil {
		client.close()
	}
	if err == nil || !strings.Contains(err.Error(), "pi-install") {
		t.Fatalf("missing Pi should give an actionable error: %v", err)
	}
}
