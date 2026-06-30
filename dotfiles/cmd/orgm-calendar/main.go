package main

import (
	"os"

	"github.com/osmargm1202/nixos/internal/calendar"
	"github.com/osmargm1202/nixos/internal/cli"
)

func main() {
	if err := calendar.Run(os.Args[1:], os.Stdout, os.Stderr); err != nil {
		os.Exit(cli.PrintError(os.Stderr, err))
	}
}
