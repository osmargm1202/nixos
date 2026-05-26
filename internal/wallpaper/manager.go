package wallpaper

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"math/rand"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

const mpvpaperWallpaperPattern = `^([^ ]+/)?(nvidia-offload )?([^ ]+/)?mpvpaper .*wallpapers`

// Manager preserves the historical hypr-random-wallpaper state paths and side effects.
type Manager struct {
	Home               string
	StaticDir          string
	VideoDir           string
	Fallback           string
	Interval           string
	MPVOptions         string
	MPVGPU             string
	KillBin            string
	RuntimeDir         string
	StateHome          string
	StateDir           string
	StateFile          string
	CurrentFile        string
	LockWallpaper      string
	DaemonPIDFile      string
	MPVPaperPIDFile    string
	HyprpaperConf      string
	QuickshellData     string
	QuickshellRequest  string
	QuickshellManifest string
	QuickshellPIDFile  string
	QuickshellConfig   string
	HyprpaperBin       string
	MPVPaperBin        string
	Stdout             io.Writer
	Stderr             io.Writer
}

// NewManager returns a wallpaper manager configured from the current environment.
func NewManager(stdout, stderr io.Writer) *Manager {
	home := envDefault("HOME", "")
	runtimeDir := envDefault("XDG_RUNTIME_DIR", "/tmp")
	stateHome := envDefault("XDG_STATE_HOME", filepath.Join(home, ".local/state"))
	stateDir := filepath.Join(stateHome, "hypr-wallpaper")
	configHome := envDefault("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	m := &Manager{
		Home:               home,
		StaticDir:          envDefault("HYPR_STATIC_WALLPAPER_DIR", filepath.Join(home, "Pictures/Wallpapers")),
		VideoDir:           envDefault("HYPR_VIDEO_WALLPAPER_DIR", filepath.Join(home, "Videos/wallpapers")),
		Fallback:           envDefault("HYPR_WALLPAPER_FALLBACK", filepath.Join(home, ".config/wallpapers/xnm1-background.png")),
		Interval:           envDefault("HYPR_WALLPAPER_INTERVAL", "3600"),
		MPVOptions:         envDefault("HYPR_MPV_WALLPAPER_OPTS", "no-audio loop hwdec=auto"),
		MPVGPU:             envDefault("HYPR_MPV_WALLPAPER_GPU", "auto"),
		KillBin:            envDefault("HYPR_WALLPAPER_KILL_BIN", "kill"),
		RuntimeDir:         runtimeDir,
		StateHome:          stateHome,
		StateDir:           stateDir,
		StateFile:          filepath.Join(stateDir, "state"),
		CurrentFile:        filepath.Join(runtimeDir, "hypr-random-wallpaper.current"),
		LockWallpaper:      filepath.Join(runtimeDir, "hypr-current-wallpaper"),
		DaemonPIDFile:      filepath.Join(runtimeDir, "hypr-random-wallpaper.daemon.pid"),
		MPVPaperPIDFile:    filepath.Join(runtimeDir, "hypr-random-wallpaper.mpvpaper.pid"),
		HyprpaperConf:      filepath.Join(runtimeDir, "hypr-random-wallpaper.hyprpaper.conf"),
		QuickshellData:     filepath.Join(stateDir, "wallpaper-picker.json"),
		QuickshellRequest:  filepath.Join(stateDir, "wallpaper-picker-request.json"),
		QuickshellManifest: filepath.Join(stateDir, "wallpaper-picker.tsv"),
		QuickshellPIDFile:  filepath.Join(runtimeDir, "hypr-wallpaper-quickshell.pid"),
		QuickshellConfig:   envDefault("HYPR_WALLPAPER_QUICKSHELL_DIR", filepath.Join(configHome, "quickshell/wallpaper-picker")),
		Stdout:             stdout,
		Stderr:             stderr,
	}
	m.HyprpaperBin = resolveBinary("HYPRPAPER_BIN", "hyprpaper")
	m.MPVPaperBin = resolveBinary("MPVPAPER_BIN", "mpvpaper")
	return m
}

func envDefault(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func resolveBinary(envKey, name string) string {
	if v := os.Getenv(envKey); v != "" && isExecutable(v) {
		return v
	}
	if p, err := exec.LookPath(name); err == nil {
		return p
	}
	candidate := filepath.Join("/run/current-system/sw/bin", name)
	if isExecutable(candidate) {
		return candidate
	}
	return name
}

func isExecutable(path string) bool {
	info, err := os.Stat(path)
	return err == nil && !info.IsDir() && info.Mode()&0111 != 0
}

func (m *Manager) ensureDirs() error {
	for _, dir := range []string{m.StaticDir, m.VideoDir, m.StateDir} {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			return err
		}
	}
	return nil
}

func (m *Manager) cmd(name string, args ...string) *exec.Cmd {
	cmd := exec.Command(name, args...)
	cmd.Stdout = m.Stdout
	cmd.Stderr = m.Stderr
	return cmd
}

func (m *Manager) runIgnore(name string, args ...string) {
	_ = m.cmd(name, args...).Run()
}

func (m *Manager) sleep(seconds string) {
	m.runIgnore("sleep", seconds)
}

func (m *Manager) StateValue(key string) string {
	file, err := os.Open(m.StateFile)
	if err != nil {
		return ""
	}
	defer file.Close()
	scanner := bufio.NewScanner(file)
	prefix := key + "="
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, prefix) {
			return strings.TrimPrefix(line, prefix)
		}
	}
	return ""
}

func (m *Manager) CurrentMode() string {
	mode := m.StateValue("mode")
	if mode == "" {
		return "static-random"
	}
	return mode
}

func (m *Manager) WriteState(mode, path string) error {
	if err := os.MkdirAll(m.StateDir, 0o755); err != nil {
		return err
	}
	tmp := fmt.Sprintf("%s.%d", m.StateFile, os.Getpid())
	content := fmt.Sprintf("mode=%s\npath=%s\n", mode, path)
	if err := os.WriteFile(tmp, []byte(content), 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, m.StateFile)
}

func (m *Manager) Status() error {
	_, err := fmt.Fprintf(m.Stdout, "mode=%s\npath=%s\n", m.CurrentMode(), m.StateValue("path"))
	return err
}

func (m *Manager) StaticWallpapers() ([]string, error) {
	return findWallpapers(m.StaticDir, map[string]bool{".jpg": true, ".jpeg": true, ".png": true, ".webp": true})
}

func (m *Manager) VideoWallpapers() ([]string, error) {
	return findWallpapers(m.VideoDir, map[string]bool{".mp4": true, ".webm": true, ".mkv": true, ".mov": true, ".m4v": true})
}

func findWallpapers(root string, exts map[string]bool) ([]string, error) {
	var paths []string
	if _, err := os.Stat(root); err != nil {
		if os.IsNotExist(err) {
			return paths, nil
		}
		return nil, err
	}
	err := filepath.WalkDir(root, func(path string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if entry.IsDir() {
			if entry.Name() == ".thumb" {
				return filepath.SkipDir
			}
			return nil
		}
		if exts[strings.ToLower(filepath.Ext(path))] {
			paths = append(paths, path)
		}
		return nil
	})
	sort.Strings(paths)
	return paths, err
}

func (m *Manager) OrderedWallpapers(mode string) ([]string, error) {
	var items []string
	var err error
	if mode == "video" {
		items, err = m.VideoWallpapers()
	} else {
		items, err = m.StaticWallpapers()
	}
	if err != nil {
		return nil, err
	}
	current := ""
	if m.CurrentMode() == mode {
		current = m.StateValue("path")
	}
	if current == "" {
		return items, nil
	}
	ordered := []string{}
	for _, item := range items {
		if item == current {
			ordered = append(ordered, item)
		}
	}
	for _, item := range items {
		if item != current {
			ordered = append(ordered, item)
		}
	}
	return ordered, nil
}

func (m *Manager) pickStatic() (string, error) {
	items, err := m.StaticWallpapers()
	if err != nil || len(items) == 0 {
		return "", err
	}
	return randomChoice(items), nil
}

func (m *Manager) pickVideo() (string, error) {
	items, err := m.VideoWallpapers()
	if err != nil || len(items) == 0 {
		return "", err
	}
	return randomChoice(items), nil
}

func randomChoice(items []string) string {
	if len(items) == 1 {
		return items[0]
	}
	return items[rand.New(rand.NewSource(time.Now().UnixNano())).Intn(len(items))]
}

func (m *Manager) writeHyprpaperConfig(wallpaper string) error {
	content := fmt.Sprintf("ipc = false\nsplash = false\nwallpaper {\n    monitor = *\n    fit_mode = cover\n    path = %s\n}\n", wallpaper)
	return os.WriteFile(m.HyprpaperConf, []byte(content), 0o644)
}

func (m *Manager) restartHyprpaper() error {
	m.runIgnore("pkill", "-x", "hyprpaper")
	if hasCommandOrPath(m.HyprpaperBin) {
		cmd := m.cmd(m.HyprpaperBin, "-c", m.HyprpaperConf)
		cmd.Stdout, cmd.Stderr = logFile("/tmp/hyprpaper.log")
		if err := cmd.Start(); err != nil {
			return err
		}
	} else if commandExists("distrobox-host-exec") {
		m.runIgnore("distrobox-host-exec", "sh", "-lc", fmt.Sprintf("pkill -x hyprpaper >/dev/null 2>&1 || true; hyprpaper -c %s >/tmp/hyprpaper.log 2>&1 &", shellQuote(m.HyprpaperConf)))
	} else {
		return fmt.Errorf("hyprpaper not found")
	}
	m.sleep("1")
	return nil
}

func logFile(path string) (*os.File, *os.File) {
	file, err := os.Create(path)
	if err != nil {
		return os.Stdout, os.Stderr
	}
	return file, file
}

func commandExists(name string) bool {
	_, err := exec.LookPath(name)
	return err == nil
}

func hasCommandOrPath(path string) bool {
	return commandExists(path) || isExecutable(path)
}

func (m *Manager) StopMPVPaper() {
	if b, err := os.ReadFile(m.MPVPaperPIDFile); err == nil {
		pid := strings.TrimSpace(string(b))
		if isNumeric(pid) {
			out, _ := exec.Command("ps", "-p", pid, "-o", "command=").Output()
			if strings.Contains(string(out), "mpvpaper") {
				m.runIgnore(m.KillBin, "-TERM", pid)
				m.sleep("0.2")
				m.runIgnore(m.KillBin, "-KILL", pid)
			}
		}
		_ = os.Remove(m.MPVPaperPIDFile)
	}
	m.runIgnore("pkill", "-f", mpvpaperWallpaperPattern)
	if commandExists("distrobox-host-exec") {
		m.runIgnore("distrobox-host-exec", "sh", "-lc", "pkill -f "+shellQuote(mpvpaperWallpaperPattern)+" >/dev/null 2>&1 || true")
	}
}

func isNumeric(s string) bool {
	if s == "" {
		return false
	}
	for _, r := range s {
		if r < '0' || r > '9' {
			return false
		}
	}
	return true
}

func (m *Manager) useNvidiaOffload() (bool, error) {
	switch m.MPVGPU {
	case "nvidia", "auto":
		return commandExists("nvidia-offload"), nil
	case "integrated", "none", "off", "false", "0":
		return false, nil
	default:
		return false, fmt.Errorf("Unknown HYPR_MPV_WALLPAPER_GPU=%s; use auto, nvidia, or integrated", m.MPVGPU)
	}
}

func (m *Manager) StartMPVPaper(video string) error {
	m.StopMPVPaper()
	if hasCommandOrPath(m.MPVPaperBin) {
		useOffload, err := m.useNvidiaOffload()
		if err != nil {
			return err
		}
		args := []string{}
		bin := m.MPVPaperBin
		if useOffload {
			args = append(args, m.MPVPaperBin)
			bin = "nvidia-offload"
		}
		args = append(args, "-o", m.MPVOptions, "*", video)
		cmd := m.cmd(bin, args...)
		cmd.Stdout, cmd.Stderr = logFile("/tmp/mpvpaper.log")
		if err := cmd.Start(); err != nil {
			return err
		}
		_ = os.WriteFile(m.MPVPaperPIDFile, []byte(strconv.Itoa(cmd.Process.Pid)+"\n"), 0o644)
	} else if commandExists("distrobox-host-exec") {
		opts := shellQuote(m.MPVOptions)
		videoQ := shellQuote(video)
		script := ""
		switch m.MPVGPU {
		case "nvidia", "auto":
			script = fmt.Sprintf("pkill -f %s >/dev/null 2>&1 || true; ( if command -v nvidia-offload >/dev/null 2>&1; then exec nvidia-offload mpvpaper -o %s '*' %s; else exec mpvpaper -o %s '*' %s; fi ) >/tmp/mpvpaper.log 2>&1 &", shellQuote(mpvpaperWallpaperPattern), opts, videoQ, opts, videoQ)
		default:
			script = fmt.Sprintf("pkill -f %s >/dev/null 2>&1 || true; mpvpaper -o %s '*' %s >/tmp/mpvpaper.log 2>&1 &", shellQuote(mpvpaperWallpaperPattern), opts, videoQ)
		}
		m.runIgnore("distrobox-host-exec", "sh", "-lc", script)
	} else {
		return fmt.Errorf("mpvpaper not found")
	}
	m.sleep("1")
	return nil
}

func (m *Manager) ensureLockWallpaper() {
	_, _ = m.CompatibilityCurrent()
}

func (m *Manager) CompatibilityCurrent() (string, error) {
	wallpaper := readTrim(m.CurrentFile)
	if wallpaper == "" || !fileExists(wallpaper) {
		wallpaper = m.Fallback
	}
	if wallpaper == "" || !fileExists(wallpaper) {
		return m.LockWallpaper, nil
	}
	if err := os.MkdirAll(filepath.Dir(m.LockWallpaper), 0o755); err != nil {
		return "", err
	}
	_ = os.Remove(m.LockWallpaper)
	if err := os.Symlink(wallpaper, m.LockWallpaper); err != nil {
		return "", err
	}
	return m.LockWallpaper, nil
}

func readTrim(path string) string {
	b, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

func fileExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && !info.IsDir()
}

func (m *Manager) SetStatic(path, mode string) error {
	if err := m.ensureDirs(); err != nil {
		return err
	}
	if !fileExists(path) {
		return fmt.Errorf("Wallpaper not found: %s", path)
	}
	m.StopMPVPaper()
	if err := m.writeHyprpaperConfig(path); err != nil {
		return err
	}
	if err := m.restartHyprpaper(); err != nil {
		return err
	}
	if err := os.WriteFile(m.CurrentFile, []byte(path+"\n"), 0o644); err != nil {
		return err
	}
	_ = os.Remove(m.LockWallpaper)
	_ = os.Symlink(path, m.LockWallpaper)
	return m.WriteState(mode, path)
}

func (m *Manager) SetRandomStatic() error {
	wallpaper, err := m.pickStatic()
	if err != nil {
		return err
	}
	if wallpaper == "" {
		wallpaper = m.Fallback
	}
	return m.SetStatic(wallpaper, "static-random")
}

func (m *Manager) StopOldDaemon() {
	if out, err := exec.Command("pgrep", "-f", "^/bin/sh "+m.Home+"/.local/bin/hypr-random-wallpaper").Output(); err == nil {
		for _, pid := range strings.Fields(string(out)) {
			if pid != strconv.Itoa(os.Getpid()) && m.cmd(m.KillBin, "-0", pid).Run() == nil {
				m.runIgnore(m.KillBin, "-KILL", pid)
			}
		}
	}
	if pid := readTrim(m.DaemonPIDFile); isNumeric(pid) && pid != strconv.Itoa(os.Getpid()) && m.cmd(m.KillBin, "-0", pid).Run() == nil && m.isWallpaperDaemonPID(pid) {
		m.runIgnore(m.KillBin, "-KILL", pid)
	}
}

func (m *Manager) isWallpaperDaemonPID(pid string) bool {
	out, err := exec.Command("ps", "-p", pid, "-o", "command=").Output()
	if err != nil {
		return false
	}
	cmdline := string(out)
	return strings.Contains(cmdline, "hypr-random-wallpaper daemon") || strings.Contains(cmdline, "orgm-hypr wallpaper daemon")
}

func (m *Manager) SetVideo(path string) error {
	if err := m.ensureDirs(); err != nil {
		return err
	}
	m.StopOldDaemon()
	if !fileExists(path) {
		return fmt.Errorf("Video wallpaper not found: %s", path)
	}
	m.runIgnore("pkill", "-x", "hyprpaper")
	if err := m.StartMPVPaper(path); err != nil {
		return err
	}
	m.ensureLockWallpaper()
	return m.WriteState("video", path)
}

func (m *Manager) SetRandomVideo() error {
	video, err := m.pickVideo()
	if err != nil {
		return err
	}
	if video == "" {
		return fmt.Errorf("No video wallpapers found in %s", m.VideoDir)
	}
	return m.SetVideo(video)
}

func (m *Manager) Restore() error {
	mode := m.CurrentMode()
	path := m.StateValue("path")
	if path != "" && fileExists(path) {
		switch mode {
		case "video":
			return m.SetVideo(path)
		case "static", "static-random":
			return m.SetStatic(path, mode)
		}
		return m.SetRandomStatic()
	}
	if mode == "video" {
		if err := m.SetRandomVideo(); err == nil {
			return nil
		}
	}
	return m.SetRandomStatic()
}

func (m *Manager) MenuPick() error {
	return m.OpenUnifiedQuickshellPicker()
}

func (m *Manager) dataPathForMode(mode string) string {
	return filepath.Join(m.StateDir, "wallpaper-picker-"+mode+".json")
}

func (m *Manager) WriteQuickshellRequest(mode, dataPath string) error {
	request := map[string]string{"mode": mode, "dataPath": dataPath, "nonce": strconv.FormatInt(time.Now().UnixNano(), 10)}
	tmp := fmt.Sprintf("%s.%d", m.QuickshellRequest, os.Getpid())
	file, err := os.Create(tmp)
	if err != nil {
		return err
	}
	encoder := json.NewEncoder(file)
	encoder.SetEscapeHTML(false)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(request); err != nil {
		_ = file.Close()
		return err
	}
	if err := file.Close(); err != nil {
		return err
	}
	return os.Rename(tmp, m.QuickshellRequest)
}

func (m *Manager) GenerateQuickshellData(mode, jsonPath string) error {
	if err := m.ensureDirs(); err != nil {
		return err
	}
	manifestTmp := fmt.Sprintf("%s.%d", m.QuickshellManifest, os.Getpid())
	mf, err := os.Create(manifestTmp)
	if err != nil {
		return err
	}
	static, err := m.OrderedWallpapers("static")
	if err != nil {
		_ = mf.Close()
		return err
	}
	video, err := m.OrderedWallpapers("video")
	if err != nil {
		_ = mf.Close()
		return err
	}
	for _, path := range static {
		fmt.Fprintf(mf, "static\t%s\n", path)
	}
	for _, path := range video {
		fmt.Fprintf(mf, "video\t%s\n", path)
	}
	if err := mf.Close(); err != nil {
		return err
	}
	if err := os.Rename(manifestTmp, m.QuickshellManifest); err != nil {
		return err
	}
	root := m.StaticDir
	if mode == "video" {
		root = m.VideoDir
	}
	_ = CleanStaleThumbnails(root)
	current := ""
	if m.CurrentMode() == mode {
		current = m.StateValue("path")
	}
	tmpJSON := fmt.Sprintf("%s.%d", jsonPath, os.Getpid())
	if err := GeneratePickerData(DataOptions{Mode: mode, ManifestPath: m.QuickshellManifest, JSONPath: tmpJSON, CurrentPath: current, Script: "orgm-hypr", ScriptArgs: []string{"wallpaper"}}); err != nil {
		return err
	}
	return os.Rename(tmpJSON, jsonPath)
}

func (m *Manager) GenerateCombinedQuickshellData(jsonPath string) error {
	if err := m.ensureDirs(); err != nil {
		return err
	}
	manifestTmp := fmt.Sprintf("%s.%d", m.QuickshellManifest, os.Getpid())
	mf, err := os.Create(manifestTmp)
	if err != nil {
		return err
	}
	static, err := m.OrderedWallpapers("static")
	if err != nil {
		_ = mf.Close()
		return err
	}
	video, err := m.OrderedWallpapers("video")
	if err != nil {
		_ = mf.Close()
		return err
	}
	for _, path := range static {
		fmt.Fprintf(mf, "static\t%s\n", path)
	}
	for _, path := range video {
		fmt.Fprintf(mf, "video\t%s\n", path)
	}
	if err := mf.Close(); err != nil {
		return err
	}
	if err := os.Rename(manifestTmp, m.QuickshellManifest); err != nil {
		return err
	}
	_ = CleanStaleThumbnails(m.StaticDir)
	_ = CleanStaleThumbnails(m.VideoDir)

	currentMode := m.CurrentMode()
	currentPath := m.StateValue("path")
	tmpJSON := fmt.Sprintf("%s.%d", jsonPath, os.Getpid())
	if err := GenerateCombinedPickerData(CombinedDataOptions{
		ManifestPath: m.QuickshellManifest,
		JSONPath:     tmpJSON,
		CurrentMode:  currentMode,
		CurrentPath:  currentPath,
		Script:       "orgm-hypr",
		ScriptArgs:   []string{"wallpaper"},
	}); err != nil {
		return err
	}
	return os.Rename(tmpJSON, jsonPath)
}

func (m *Manager) WallpaperThumb(path string) (string, error) {
	thumb := filepath.Join(filepath.Dir(path), ".thumb", filepath.Base(path)+".jpg")
	if info, err := os.Stat(thumb); err == nil && info.Size() > 0 {
		return thumb, nil
	}
	if err := os.MkdirAll(filepath.Dir(thumb), 0o755); err != nil {
		return "", err
	}
	cmd := m.cmd("ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", path, "-frames:v", "1", "-vf", "scale=320:-1", thumb)
	if err := cmd.Run(); err != nil {
		return "", err
	}
	return thumb, nil
}

func (m *Manager) WarmThumbs(mode, index string, radius int) error {
	items, err := m.itemsFromManifest(mode)
	if err != nil {
		return err
	}
	if index == "all" {
		for _, item := range items {
			_, _ = m.WallpaperThumb(item)
		}
		return nil
	}
	idx, err := strconv.Atoi(index)
	if err != nil {
		idx = 0
	}
	start := idx - radius
	if start < 0 {
		start = 0
	}
	end := idx + radius
	if end >= len(items) {
		end = len(items) - 1
	}
	for i := start; i <= end && i >= 0; i++ {
		_, _ = m.WallpaperThumb(items[i])
	}
	return nil
}

func (m *Manager) WarmPage(mode string, page, pageSize int) error {
	items, err := m.itemsFromManifest(mode)
	if err != nil {
		return err
	}
	start := page * pageSize
	end := start + pageSize - 1
	if start >= len(items) {
		return nil
	}
	if end >= len(items) {
		end = len(items) - 1
	}
	for i := start; i <= end; i++ {
		_, _ = m.WallpaperThumb(items[i])
	}
	return nil
}

func (m *Manager) itemsFromManifest(mode string) ([]string, error) {
	file, err := os.Open(m.QuickshellManifest)
	if err != nil {
		return nil, err
	}
	defer file.Close()
	var items []string
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		rowMode, path, ok := strings.Cut(scanner.Text(), "\t")
		if ok && rowMode == mode {
			items = append(items, path)
		}
	}
	return items, scanner.Err()
}

func (m *Manager) OpenQuickshellCarousel(mode string) error {
	dataPath := m.dataPathForMode(mode)
	if err := m.GenerateQuickshellData(mode, dataPath); err != nil {
		return err
	}
	input, err := os.ReadFile(dataPath)
	if err != nil {
		return err
	}
	if err := os.WriteFile(m.QuickshellData, input, 0o644); err != nil {
		return err
	}
	if err := m.WriteQuickshellRequest(mode, dataPath); err != nil {
		return err
	}
	return m.StartQuickshellPicker(true)
}

func (m *Manager) OpenUnifiedQuickshellPicker() error {
	dataPath := filepath.Join(m.StateDir, "wallpaper-picker-combined.json")
	if err := m.GenerateCombinedQuickshellData(dataPath); err != nil {
		return err
	}
	input, err := os.ReadFile(dataPath)
	if err != nil {
		return err
	}
	if err := os.WriteFile(m.QuickshellData, input, 0o644); err != nil {
		return err
	}
	if err := m.WriteQuickshellRequest("combined", dataPath); err != nil {
		return err
	}
	return m.StartQuickshellPicker(true)
}

func (m *Manager) quickshellRunning() bool {
	pid := readTrim(m.QuickshellPIDFile)
	if isNumeric(pid) && exec.Command("kill", "-0", pid).Run() == nil {
		out, _ := exec.Command("ps", "-p", pid, "-o", "command=").Output()
		cmdline := string(out)
		if strings.Contains(cmdline, "quickshell") && strings.Contains(cmdline, "wallpaper-picker") {
			return true
		}
	}
	out, err := exec.Command("pgrep", "-f", "quickshell .*wallpaper-picker").Output()
	return err == nil && strings.TrimSpace(string(out)) != ""
}

func (m *Manager) StartQuickshellPicker(show bool) error {
	if m.quickshellRunning() {
		if !show {
			return nil
		}
		m.runIgnore("pkill", "-f", "quickshell .*wallpaper-picker")
		_ = os.Remove(m.QuickshellPIDFile)
	}
	showFlag := "0"
	if show {
		showFlag = "1"
	}
	if commandExists("quickshell") {
		cmd := m.cmd("quickshell", "-p", m.QuickshellConfig)
		cmd.Env = append(os.Environ(), "HYPR_WALLPAPER_DATA="+m.QuickshellData, "HYPR_WALLPAPER_REQUEST="+m.QuickshellRequest, "HYPR_WALLPAPER_SHOW="+showFlag)
		cmd.Stdout, cmd.Stderr = logFile("/tmp/hypr-wallpaper-quickshell.log")
		if err := cmd.Start(); err != nil {
			return err
		}
		return os.WriteFile(m.QuickshellPIDFile, []byte(strconv.Itoa(cmd.Process.Pid)+"\n"), 0o644)
	}
	if commandExists("distrobox-host-exec") {
		script := fmt.Sprintf("HYPR_WALLPAPER_DATA=%s HYPR_WALLPAPER_REQUEST=%s HYPR_WALLPAPER_SHOW=%s quickshell -p %s >/tmp/hypr-wallpaper-quickshell.log 2>&1 &", shellQuote(m.QuickshellData), shellQuote(m.QuickshellRequest), shellQuote(showFlag), shellQuote(m.QuickshellConfig))
		m.runIgnore("distrobox-host-exec", "sh", "-lc", script)
		return nil
	}
	return fmt.Errorf("quickshell not found")
}

func (m *Manager) RunDaemon() error {
	m.StopOldDaemon()
	if err := os.WriteFile(m.DaemonPIDFile, []byte(strconv.Itoa(os.Getpid())+"\n"), 0o644); err != nil {
		return err
	}
	if err := m.Restore(); err != nil {
		return err
	}
	for {
		m.sleep(m.Interval)
		if m.CurrentMode() == "static-random" {
			_ = m.SetRandomStatic()
		}
	}
}

func shellQuote(s string) string {
	return "'" + strings.ReplaceAll(s, "'", "'\\''") + "'"
}
