package dotcli

import (
	"fmt"
	"strings"
)

// Command is the parsed orgm-dot command line.
type Command struct {
	Name      string
	Host      string
	Scope     string
	Target    string
	DryRun    bool
	NoColor   bool
	Porcelain bool
	Verbose   bool
	Interval  string
	Config    string
}

// Parse converts orgm-dot arguments into a Command.
func Parse(args []string) (Command, error) {
	var cmd Command
	for i := 0; i < len(args); i++ {
		arg := args[i]
		switch arg {
		case "version", "diff", "sync", "daemon", "install", "status":
			if cmd.Name != "" {
				return Command{}, fmt.Errorf("only one command is allowed")
			}
			cmd.Name = arg
		case "--diff", "--sync", "--daemon", "--install", "--status":
			if cmd.Name != "" {
				return Command{}, fmt.Errorf("only one command is allowed")
			}
			cmd.Name = arg[2:]
		case "add", "remove":
			if cmd.Name != "" {
				return Command{}, fmt.Errorf("only one command is allowed")
			}
			cmd.Name = arg
			target, next, err := nextValue(args, i, cmd.Name+" requires PATH")
			if err != nil {
				return Command{}, err
			}
			cmd.Target = target
			i = next
		case "--add", "--remove":
			if cmd.Name != "" {
				return Command{}, fmt.Errorf("only one command is allowed")
			}
			cmd.Name = arg[2:]
			target, next, err := nextValue(args, i, cmd.Name+" requires PATH")
			if err != nil {
				return Command{}, err
			}
			cmd.Target = target
			i = next
		case "--host":
			host, next, err := nextValue(args, i, "--host requires a value")
			if err != nil {
				return Command{}, err
			}
			cmd.Host = host
			cmd.Scope = "host"
			i = next
		case "--shared":
			cmd.Scope = "shared"
		case "--dry-run":
			cmd.DryRun = true
		case "--no-color":
			cmd.NoColor = true
		case "--porcelain":
			cmd.Porcelain = true
			cmd.NoColor = true
		case "--verbose", "-v":
			cmd.Verbose = true
		case "--interval":
			interval, next, err := nextValue(args, i, "--interval requires seconds")
			if err != nil {
				return Command{}, err
			}
			cmd.Interval = interval
			i = next
		case "--config":
			config, next, err := nextValue(args, i, "--config requires path")
			if err != nil {
				return Command{}, err
			}
			cmd.Config = config
			i = next
		case "--help", "-h":
			cmd.Name = "help"
		default:
			if cmd.Name == "sync" && cmd.Target == "" && !strings.HasPrefix(arg, "-") {
				cmd.Target = arg
				continue
			}
			if cmd.Name == "sync" && cmd.Target != "" && !strings.HasPrefix(arg, "-") {
				return Command{}, fmt.Errorf("sync accepts at most one PATH")
			}
			return Command{}, fmt.Errorf("unknown argument: %s", arg)
		}
	}
	if cmd.Name == "" {
		return Command{}, fmt.Errorf("command is required")
	}
	return cmd, nil
}

func nextValue(args []string, index int, message string) (string, int, error) {
	next := index + 1
	if next >= len(args) {
		return "", index, fmt.Errorf("%s", message)
	}
	return args[next], next, nil
}

func (c Command) RequireHost() error {
	if c.Host == "" {
		return fmt.Errorf("--host is required")
	}
	return nil
}

func (c Command) RequireScope() error {
	switch c.Scope {
	case "shared":
		return nil
	case "host":
		if c.Host == "" {
			return fmt.Errorf("--host is required for host scope")
		}
		return nil
	default:
		return fmt.Errorf("choose --shared or --host HOST")
	}
}
