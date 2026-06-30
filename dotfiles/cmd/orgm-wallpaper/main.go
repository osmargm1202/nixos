package main

import (
	"flag"
	"fmt"
	"io"
	"os"
	"strconv"

	"github.com/osmargm1202/nixos/internal/cli"
	"github.com/osmargm1202/nixos/internal/wallpaper"
)

func main() {
	if err := run(os.Args[1:]); err != nil {
		os.Exit(cli.PrintError(os.Stderr, err))
	}
}

func run(args []string) error {
	return runWithIO(args, os.Stdout, os.Stderr)
}

func runWithIO(args []string, stdout, stderr io.Writer) error {
	m := wallpaper.NewManager(stdout, stderr)
	if len(args) < 1 {
		return cli.UsageError(usage())
	}

	switch args[0] {
	case "data":
		flags := flag.NewFlagSet("orgm-wallpaper data", flag.ContinueOnError)
		flags.SetOutput(stderr)
		var opts wallpaper.DataOptions
		var scriptArgs csvFlag
		flags.StringVar(&opts.Mode, "mode", "", "wallpaper mode: static or video")
		flags.StringVar(&opts.ManifestPath, "manifest", "", "TSV manifest path")
		flags.StringVar(&opts.JSONPath, "json", "", "Quickshell JSON output path")
		flags.StringVar(&opts.CurrentPath, "current", "", "current wallpaper path")
		flags.StringVar(&opts.Script, "script", "orgm-wallpaper", "script/command used by Quickshell apply actions")
		flags.Var(&scriptArgs, "script-arg", "extra script argument for Quickshell actions; may be repeated")
		if err := flags.Parse(args[1:]); err != nil {
			return cli.UsageError(err.Error())
		}
		if flags.NArg() != 0 {
			return cli.UsageError("unexpected argument: %s", flags.Arg(0))
		}
		opts.ScriptArgs = []string(scriptArgs)
		return wallpaper.GeneratePickerData(opts)
	case "clean-thumbs":
		flags := flag.NewFlagSet("orgm-wallpaper clean-thumbs", flag.ContinueOnError)
		flags.SetOutput(stderr)
		var root string
		flags.StringVar(&root, "root", "", "wallpaper root containing folder-local .thumb caches")
		if err := flags.Parse(args[1:]); err != nil {
			return cli.UsageError(err.Error())
		}
		if flags.NArg() != 0 {
			return cli.UsageError("unexpected argument: %s", flags.Arg(0))
		}
		if root == "" {
			return cli.UsageError("root path is required")
		}
		return wallpaper.CleanStaleThumbnails(root)
	case "status":
		flags := flag.NewFlagSet("orgm-wallpaper status", flag.ContinueOnError)
		flags.SetOutput(stderr)
		monitor := flags.String("monitor", "", "Hyprland output name")
		if err := flags.Parse(args[1:]); err != nil {
			return cli.UsageError(err.Error())
		}
		if flags.NArg() != 0 {
			return cli.UsageError("unexpected argument: %s", flags.Arg(0))
		}
		if *monitor != "" {
			return m.StatusForMonitor(*monitor)
		}
		return m.Status()
	case "restore":
		return m.Restore()
	case "set-static":
		if len(args) < 2 {
			return cli.UsageError("usage: orgm-wallpaper set-static PATH [--monitor OUTPUT]")
		}
		path := args[1]
		flags := flag.NewFlagSet("orgm-wallpaper set-static", flag.ContinueOnError)
		flags.SetOutput(stderr)
		monitor := flags.String("monitor", "", "Hyprland output name")
		if err := flags.Parse(args[2:]); err != nil {
			return cli.UsageError(err.Error())
		}
		if flags.NArg() != 0 {
			return cli.UsageError("unexpected argument: %s", flags.Arg(0))
		}
		if *monitor != "" {
			return m.SetStaticForMonitor(path, *monitor, "static")
		}
		return m.SetStatic(path, "static")
	case "random-static":
		flags := flag.NewFlagSet("orgm-wallpaper random-static", flag.ContinueOnError)
		flags.SetOutput(stderr)
		monitor := flags.String("monitor", "", "Hyprland output name")
		if err := flags.Parse(args[1:]); err != nil {
			return cli.UsageError(err.Error())
		}
		if flags.NArg() != 0 {
			return cli.UsageError("unexpected argument: %s", flags.Arg(0))
		}
		if *monitor != "" {
			return m.SetRandomStaticForMonitor(*monitor)
		}
		return m.SetRandomStatic()
	case "random-video":
		flags := flag.NewFlagSet("orgm-wallpaper random-video", flag.ContinueOnError)
		flags.SetOutput(stderr)
		monitor := flags.String("monitor", "", "Hyprland output name")
		if err := flags.Parse(args[1:]); err != nil {
			return cli.UsageError(err.Error())
		}
		if flags.NArg() != 0 {
			return cli.UsageError("unexpected argument: %s", flags.Arg(0))
		}
		if *monitor != "" {
			return m.SetRandomVideoForMonitor(*monitor)
		}
		return m.SetRandomVideo()
	case "random":
		if len(args) < 2 {
			return cli.UsageError("usage: orgm-wallpaper random [static|video] [--monitor OUTPUT]")
		}
		flags := flag.NewFlagSet("orgm-wallpaper random", flag.ContinueOnError)
		flags.SetOutput(stderr)
		monitor := flags.String("monitor", "", "Hyprland output name")
		if err := flags.Parse(args[2:]); err != nil {
			return cli.UsageError(err.Error())
		}
		if flags.NArg() != 0 {
			return cli.UsageError("unexpected argument: %s", flags.Arg(0))
		}
		switch args[1] {
		case "static", "normal":
			if *monitor != "" {
				return m.SetRandomStaticForMonitor(*monitor)
			}
			return m.SetRandomStatic()
		case "video", "live":
			if *monitor != "" {
				return m.SetRandomVideoForMonitor(*monitor)
			}
			return m.SetRandomVideo()
		default:
			return cli.UsageError("usage: orgm-wallpaper random [static|video] [--monitor OUTPUT]")
		}
	case "set-video":
		if len(args) < 2 {
			return cli.UsageError("usage: orgm-wallpaper set-video PATH [--monitor OUTPUT]")
		}
		path := args[1]
		flags := flag.NewFlagSet("orgm-wallpaper set-video", flag.ContinueOnError)
		flags.SetOutput(stderr)
		monitor := flags.String("monitor", "", "Hyprland output name")
		if err := flags.Parse(args[2:]); err != nil {
			return cli.UsageError(err.Error())
		}
		if flags.NArg() != 0 {
			return cli.UsageError("unexpected argument: %s", flags.Arg(0))
		}
		if *monitor != "" {
			return m.SetVideoForMonitor(path, *monitor)
		}
		return m.SetVideo(path)
	case "warm-page":
		if len(args) != 4 {
			return cli.UsageError("usage: orgm-wallpaper warm-page [static|video] PAGE PAGE_SIZE")
		}
		page, err := strconv.Atoi(args[2])
		if err != nil {
			return cli.UsageError("invalid PAGE: %s", args[2])
		}
		pageSize, err := strconv.Atoi(args[3])
		if err != nil {
			return cli.UsageError("invalid PAGE_SIZE: %s", args[3])
		}
		return m.WarmPage(args[1], page, pageSize)
	case "pick":
		return m.MenuPick()
	case "picker-daemon":
		return m.StartQuickshellPicker(false)
	case "daemon":
		return m.RunDaemon()
	default:
		return cli.UsageError(usage())
	}
}

type csvFlag []string

func (f *csvFlag) String() string { return fmt.Sprint([]string(*f)) }

func (f *csvFlag) Set(value string) error {
	*f = append(*f, value)
	return nil
}

func usage() string {
	return "usage: orgm-wallpaper [data|status|clean-thumbs|restore|set-static|set-video|random|random-static|random-video|warm-page|pick|picker-daemon|daemon|apply-colors]"
}
