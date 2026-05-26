package dotdaemon

import (
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/osmargm1202/nixos/internal/dotconfig"
	"github.com/osmargm1202/nixos/internal/dotsync"
)

type Options struct {
	Host     string
	Interval time.Duration
}

func Run(rt dotconfig.Runtime, opts Options) error {
	if opts.Interval <= 0 {
		opts.Interval = time.Duration(rt.PollSeconds) * time.Second
	}
	if err := os.MkdirAll(rt.StateDir, 0o755); err != nil {
		return err
	}
	stateFile := filepath.Join(rt.StateDir, "last-head-"+opts.Host)
	lastBytes, _ := os.ReadFile(stateFile)
	last := string(bytesTrimSpace(lastBytes))
	fmt.Printf("orgm-dot daemon --host %s watching %s every %ss\n", opts.Host, rt.Repo, trimSeconds(opts.Interval))
	for {
		last = CheckOnce(rt, opts.Host, stateFile, last)
		time.Sleep(opts.Interval)
	}
}

func CheckOnce(rt dotconfig.Runtime, host, stateFile, last string) string {
	head := rt.CurrentHead()
	if head != "" && head != last {
		fmt.Printf("%s -> %s: syncing\n", noneIfEmpty(last), head)
		if _, err := dotsync.Run(rt, dotsync.Options{Host: host}); err != nil {
			fmt.Fprintf(os.Stderr, "orgm-dot: sync failed: %s\n", err)
			return last
		}
		_ = os.WriteFile(stateFile, []byte(head+"\n"), 0o644)
		return head
	}
	return last
}

func noneIfEmpty(value string) string {
	if value == "" {
		return "none"
	}
	return value
}

func trimSeconds(d time.Duration) string {
	return fmt.Sprintf("%.0f", d.Seconds())
}

func bytesTrimSpace(b []byte) []byte {
	for len(b) > 0 && (b[len(b)-1] == '\n' || b[len(b)-1] == '\r' || b[len(b)-1] == ' ' || b[len(b)-1] == '\t') {
		b = b[:len(b)-1]
	}
	return b
}
