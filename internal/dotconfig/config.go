package dotconfig

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/osmargm1202/nixos/internal/dotmanifest"
	"github.com/osmargm1202/nixos/internal/dotpaths"
)

type Config struct {
	Settings  Settings                   `json:"settings"`
	Shared    PathList                   `json:"shared"`
	Hosts     map[string]PathList        `json:"hosts"`
	LocalOnly dotmanifest.LocalOnlyRules `json:"local_only"`
	Diff      DiffSettings               `json:"diff"`
}

type Settings struct {
	Repo         string `json:"repo"`
	Destination  string `json:"destination"`
	SourceShared string `json:"source_shared"`
	SourceHosts  string `json:"source_hosts"`
	StateDir     string `json:"state_dir"`
	PollSeconds  int    `json:"poll_seconds"`
}

type PathList struct {
	Paths []string `json:"paths"`
}

type DiffSettings struct {
	ScanRoots []string `json:"scan_roots"`
}

type Runtime struct {
	Config       Config
	ConfigPath   string
	Repo         string
	Destination  string
	SourceShared string
	SourceHosts  string
	StateDir     string
	PollSeconds  int
	Home         string
}

func Load(configPath string) (Runtime, error) {
	home := dotpaths.HomeDir()
	defaultRepo := discoverDefaultRepo()
	if configPath == "" {
		configPath = os.Getenv("ORGM_DOT_CONFIG")
	}
	if configPath == "" {
		configPath = filepath.Join(defaultRepo, "config", "dotfiles.json")
	}
	configPath = filepath.Clean(configPath)

	content, err := os.ReadFile(configPath)
	if err != nil {
		return Runtime{}, fmt.Errorf("config not found: %s", configPath)
	}
	var cfg Config
	if err := json.Unmarshal(content, &cfg); err != nil {
		return Runtime{}, err
	}

	repo := cfg.Settings.Repo
	if repo == "" {
		repo = defaultRepo
	}
	repo = dotpaths.Expand(repo, defaultRepo, home)

	destination := cfg.Settings.Destination
	if destination == "" {
		destination = home
	}
	destination = dotpaths.Expand(destination, repo, home)

	sourceShared := dotpaths.Expand(cfg.Settings.SourceShared, repo, home)
	sourceHosts := dotpaths.Expand(cfg.Settings.SourceHosts, repo, home)
	stateDir := dotpaths.Expand(cfg.Settings.StateDir, repo, home)
	pollSeconds := cfg.Settings.PollSeconds
	if pollSeconds == 0 {
		pollSeconds = 5
	}

	return Runtime{
		Config:       cfg,
		ConfigPath:   configPath,
		Repo:         repo,
		Destination:  destination,
		SourceShared: sourceShared,
		SourceHosts:  sourceHosts,
		StateDir:     stateDir,
		PollSeconds:  pollSeconds,
		Home:         home,
	}, nil
}

func (r Runtime) HostPaths(host string) []string {
	if r.Config.Hosts == nil {
		return nil
	}
	return r.Config.Hosts[host].Paths
}

func (r Runtime) HostSource(host string) string {
	return filepath.Join(r.SourceHosts, host)
}

func (r Runtime) CurrentHead() string {
	cmd := exec.Command("git", "-C", r.Repo, "rev-parse", "HEAD")
	out, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

func discoverDefaultRepo() string {
	if repo := os.Getenv("DOTFILES_REPO"); repo != "" {
		return filepath.Clean(repo)
	}
	if repo := gitTopLevelFromWorkingDir(); repo != "" && fileExists(filepath.Join(repo, "config", "dotfiles.json")) {
		return repo
	}
	home := dotpaths.HomeDir()
	if home != "" {
		candidate := filepath.Join(home, "Hobby", "dotfiles")
		if fileExists(filepath.Join(candidate, "config", "dotfiles.json")) {
			return candidate
		}
	}
	cwd, _ := os.Getwd()
	return cwd
}

func gitTopLevelFromWorkingDir() string {
	cmd := exec.Command("git", "rev-parse", "--show-toplevel")
	out, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

func fileExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && !info.IsDir()
}

func (r Runtime) StatusLines(host string) []string {
	return []string{
		fmt.Sprintf("repo:        %s", r.Repo),
		fmt.Sprintf("config:      %s", r.ConfigPath),
		fmt.Sprintf("destination: %s", r.Destination),
		fmt.Sprintf("shared src:  %s", r.SourceShared),
		fmt.Sprintf("host src:    %s", r.HostSource(host)),
		fmt.Sprintf("head:        %s", r.CurrentHead()),
		fmt.Sprintf("state dir:   %s", r.StateDir),
		fmt.Sprintf("host:        %s", host),
		fmt.Sprintf("managed shared: %s", strconv.Itoa(len(r.Config.Shared.Paths))),
		fmt.Sprintf("managed host:   %s", strconv.Itoa(len(r.HostPaths(host)))),
	}
}
