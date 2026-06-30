package main

import (
	"fmt"
	"os"
	"strconv"
	"time"

	"github.com/osmargm1202/nixos/internal/dotadd"
	"github.com/osmargm1202/nixos/internal/dotcli"
	"github.com/osmargm1202/nixos/internal/dotconfig"
	"github.com/osmargm1202/nixos/internal/dotdaemon"
	"github.com/osmargm1202/nixos/internal/dotdiff"
	"github.com/osmargm1202/nixos/internal/dotinstall"
	"github.com/osmargm1202/nixos/internal/dotsync"
)

func main() {
	cmd, err := dotcli.Parse(os.Args[1:])
	if err != nil {
		fmt.Fprintf(os.Stderr, "orgm-dot: %s\n", err)
		fmt.Fprint(os.Stderr, dotcli.Usage)
		os.Exit(1)
	}

	switch cmd.Name {
	case "help":
		fmt.Print(dotcli.Usage)
	case "version":
		fmt.Println("orgm-dot dev")
	case "status":
		runtime, err := dotconfig.Load(cmd.Config)
		if err != nil {
			fatal(err)
		}
		host := resolveHost(runtime, cmd.Host)
		for _, line := range runtime.StatusLines(host) {
			fmt.Println(line)
		}
	case "diff":
		runtime, err := dotconfig.Load(cmd.Config)
		if err != nil {
			fatal(err)
		}
		host := resolveHost(runtime, cmd.Host)
		changes, err := dotdiff.Changes(runtime, dotdiff.Options{Host: host, Porcelain: cmd.Porcelain, Verbose: cmd.Verbose})
		if err != nil {
			fatal(err)
		}
		for _, line := range dotdiff.Format(changes, host, cmd.Porcelain) {
			fmt.Println(line)
		}
	case "sync":
		runtime, err := dotconfig.Load(cmd.Config)
		if err != nil {
			fatal(err)
		}
		host := resolveHost(runtime, cmd.Host)
		actions, err := dotsync.Run(runtime, dotsync.Options{Host: host, DryRun: cmd.DryRun, Target: cmd.Target})
		if err != nil {
			fatal(err)
		}
		if cmd.DryRun {
			for _, line := range dotsync.Format(actions) {
				fmt.Println(line)
			}
		}
	case "add":
		if err := cmd.RequireScope(); err != nil {
			fatal(err)
		}
		runtime, err := dotconfig.Load(cmd.Config)
		if err != nil {
			fatal(err)
		}
		line, err := dotadd.Add(runtime, dotadd.Options{Host: cmd.Host, Scope: cmd.Scope, Target: cmd.Target})
		if err != nil {
			fatal(err)
		}
		fmt.Println(line)
	case "remove":
		if err := cmd.RequireScope(); err != nil {
			fatal(err)
		}
		runtime, err := dotconfig.Load(cmd.Config)
		if err != nil {
			fatal(err)
		}
		line, err := dotadd.Remove(runtime, dotadd.Options{Host: cmd.Host, Scope: cmd.Scope, Target: cmd.Target})
		if err != nil {
			fatal(err)
		}
		fmt.Println(line)
	case "daemon":
		runtime, err := dotconfig.Load(cmd.Config)
		if err != nil {
			fatal(err)
		}
		host := resolveHost(runtime, cmd.Host)
		interval := time.Duration(runtime.PollSeconds) * time.Second
		if cmd.Interval != "" {
			seconds, err := strconv.Atoi(cmd.Interval)
			if err != nil || seconds <= 0 {
				fatal(fmt.Errorf("--interval requires positive seconds"))
			}
			interval = time.Duration(seconds) * time.Second
		}
		fatal(dotdaemon.Run(runtime, dotdaemon.Options{Host: host, Interval: interval}))
	case "install":
		lines, err := dotinstall.Run(dotpathsHome(), "")
		if err != nil {
			fatal(err)
		}
		for _, line := range lines {
			fmt.Println(line)
		}
	default:
		fmt.Fprintf(os.Stderr, "orgm-dot: unknown command: %s\n", cmd.Name)
		os.Exit(2)
	}
}

func resolveHost(runtime dotconfig.Runtime, explicit string) string {
	host, err := runtime.ResolveHost(explicit, dotconfig.OSHostname)
	if err != nil {
		fatal(err)
	}
	return host
}

func fatal(err error) {
	fmt.Fprintf(os.Stderr, "orgm-dot: %s\n", err)
	os.Exit(1)
}

func dotpathsHome() string {
	if home := os.Getenv("HOME"); home != "" {
		return home
	}
	home, _ := os.UserHomeDir()
	return home
}
