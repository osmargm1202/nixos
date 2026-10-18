package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

const usage = `orgm-dot: copias editables por aplicación

  orgm-dot                         Selector de aplicación y operación
  orgm-dot list                    Aplicaciones disponibles en este perfil
  orgm-dot list --all              Todos los nombres registrados en el repo
  orgm-dot show APP                Rutas y manifiesto
  orgm-dot add APP RUTA [RUTA...]   Registrar rutas relativas a HOME
  orgm-dot remove APP [--dry-run]   Dejar de guardar en este equipo/perfil
  orgm-dot diff APP [--patch]       A: nuevo del repo, M: modificado, D: solo local
  orgm-dot pull APP [--dry-run]     Reemplazar rutas locales desde el repo
  orgm-dot push APP [--dry-run]     Reemplazar copia del repo desde HOME
  orgm-dot backups                 Enumerar respaldos completos
  orgm-dot restore ID              Restaurar un respaldo (crea otro respaldo)
  orgm-dot bootstrap               Migración inicial; conserva archivos editables

Opciones: --repo PATH --home PATH --context JSON --host HOST --profile PROFILE
          --user USER --state PATH --json --patch --dry-run --all
Alias: apply = pull, save = push. Push guarda en el checkout; no hace git push.
Remove conserva HOME, crea respaldo y retira el snapshot del contexto actual.
El diff describe lo que cambiaría pull. No se reinician aplicaciones automáticamente.
`

type options struct {
	repo, home, context, host, profile, user, state string
	json, patch, dry, all                           bool
	args                                            []string
}

func parse(args []string) (options, error) {
	o := options{context: "/etc/orgm-dot/context.json"}
	for i := 0; i < len(args); i++ {
		a := args[i]
		switch a {
		case "--help":
			o.args = append(o.args, "help")
		case "--version":
			o.args = append(o.args, "version")
		case "--json":
			o.json = true
		case "--patch":
			o.patch = true
		case "--dry-run":
			o.dry = true
		case "--all":
			o.all = true
		case "--repo", "--home", "--context", "--host", "--profile", "--user", "--state":
			if i+1 == len(args) {
				return o, fmt.Errorf("%s needs a value", a)
			}
			i++
			v := args[i]
			switch a {
			case "--repo":
				o.repo = v
			case "--home":
				o.home = v
			case "--context":
				o.context = v
			case "--host":
				o.host = v
			case "--profile":
				o.profile = v
			case "--user":
				o.user = v
			case "--state":
				o.state = v
			}
		default:
			if strings.HasPrefix(a, "-") {
				return o, fmt.Errorf("unknown option: %s", a)
			}
			o.args = append(o.args, a)
		}
	}
	return o, nil
}

func runtimeFor(o options) (Runtime, error) {
	r := Runtime{}
	contextPath := o.context
	home := o.home
	if home == "" {
		home = os.Getenv("HOME")
	}
	if _, err := os.Stat(contextPath); os.IsNotExist(err) && contextPath == "/etc/orgm-dot/context.json" {
		contextPath = filepath.Join(home, ".local/state/orgm-dot/context.json")
	}
	if err := readJSON(contextPath, &r.Context); err != nil {
		return r, fmt.Errorf("context: %w", err)
	}
	if o.repo != "" {
		r.Repository = o.repo
	} else if repo := os.Getenv("ORGM_DOT_REPO"); repo != "" {
		r.Repository = repo
	}
	r.Home = o.home
	if r.Home == "" {
		r.Home = os.Getenv("HOME")
	}
	if o.host != "" {
		r.Host = o.host
	}
	if o.profile != "" {
		r.Profile = o.profile
	}
	if o.user != "" {
		r.User = o.user
	}
	r.State = o.state
	if r.Home == "" || r.Repository == "" {
		return r, fmt.Errorf("home and repository are required")
	}
	err := r.load()
	return r, err
}

func (r Runtime) available() ([]Manifest, error) {
	apps := []Manifest{}
	for _, app := range r.Apps {
		disabled, err := r.disabled(app)
		if err != nil {
			return nil, err
		}
		if disabled {
			continue
		}
		paths, err := r.savePaths(app)
		if err != nil {
			return nil, err
		}
		if len(paths) > 0 {
			apps = append(apps, app)
		}
	}
	return apps, nil
}

func menu(r Runtime) ([]string, error) {
	apps, err := r.available()
	if err != nil {
		return nil, err
	}
	for i, app := range apps {
		fmt.Printf("%2d  %s\n", i+1, app.Name)
	}
	in := bufio.NewReader(os.Stdin)
	fmt.Print("Aplicación (número o nombre): ")
	line, err := in.ReadString('\n')
	if err != nil {
		return nil, err
	}
	name := strings.TrimSpace(line)
	if n, err := strconv.Atoi(name); err == nil {
		if n < 1 || n > len(apps) {
			return nil, fmt.Errorf("invalid selection")
		}
		name = apps[n-1].Name
	}
	if _, err := r.app(name); err != nil {
		return nil, err
	}
	fmt.Print("Operación [diff/pull/push] (diff): ")
	line, err = in.ReadString('\n')
	if err != nil {
		return nil, err
	}
	action := strings.TrimSpace(line)
	if action == "" {
		action = "diff"
	}
	switch action {
	case "diff", "pull", "push":
		return []string{action, name}, nil
	}
	return nil, fmt.Errorf("invalid operation")
}

func run(args []string) error {
	o, err := parse(args)
	if err != nil {
		return err
	}
	if len(o.args) > 0 && (o.args[0] == "help" || o.args[0] == "version") {
		if o.args[0] == "version" {
			fmt.Println("orgm-dot 1.1.0")
		} else {
			fmt.Print(usage)
		}
		return nil
	}
	r, err := runtimeFor(o)
	if err != nil {
		return err
	}
	if len(o.args) == 0 {
		o.args, err = menu(r)
		if err != nil {
			return err
		}
	}
	cmd := o.args[0]
	if o.all && cmd != "list" {
		return fmt.Errorf("--all is only supported by list")
	}
	if (o.dry || o.patch || o.json) && cmd == "bootstrap" {
		return fmt.Errorf("bootstrap accepts no output or dry-run flags")
	}
	if cmd == "backups" {
		entries, err := os.ReadDir(filepath.Join(r.State, "backups"))
		if os.IsNotExist(err) {
			return nil
		}
		if err != nil {
			return err
		}
		for _, e := range entries {
			if _, err := os.Stat(filepath.Join(r.State, "backups", e.Name(), "backup.json")); err == nil {
				fmt.Println(e.Name())
			}
		}
		return nil
	}
	if cmd == "list" {
		apps, err := r.available()
		if err != nil {
			return err
		}
		if o.all {
			apps = r.Apps
		}
		if o.json {
			return json.NewEncoder(os.Stdout).Encode(apps)
		}
		for _, app := range apps {
			fmt.Println(app.Name)
		}
		return nil
	}
	unlock, err := r.lock()
	if err != nil {
		return err
	}
	defer unlock()
	if cmd == "add" {
		if len(o.args) < 3 || o.json || o.patch {
			return fmt.Errorf("use orgm-dot add APP RUTA [RUTA...]")
		}
		return r.add(Manifest{1, o.args[1], o.args[2:]}, o.dry)
	}
	if cmd == "bootstrap" {
		return r.bootstrap()
	}
	if len(o.args) != 2 {
		return fmt.Errorf("specify one application or backup; use orgm-dot help")
	}
	if cmd == "restore" {
		if o.dry {
			return fmt.Errorf("restore does not accept --dry-run")
		}
		id, err := r.restore(o.args[1])
		if err == nil {
			fmt.Println("Backup:", id)
		}
		return err
	}
	app, err := r.app(o.args[1])
	if err != nil {
		return err
	}
	switch cmd {
	case "show", "diff", "pull", "apply", "push", "save", "remove":
	default:
		return fmt.Errorf("unknown command: %s", cmd)
	}
	if cmd == "show" {
		disabled, err := r.disabled(app)
		if err != nil {
			return err
		}
		paths, err := r.savePaths(app)
		if err != nil {
			return err
		}
		return json.NewEncoder(os.Stdout).Encode(struct {
			Manifest Manifest `json:"manifest"`
			Paths    []string `json:"active_paths"`
			Snapshot string   `json:"snapshot"`
			Disabled bool     `json:"disabled"`
		}{app, paths, r.snapshot(app), disabled})
	}
	if cmd == "remove" {
		if o.json || o.patch {
			return fmt.Errorf("remove accepts --dry-run only")
		}
		if o.dry {
			fmt.Printf("Dejar de guardar %s en %s/%s/%s; retirar %s; conservar HOME.\n", app.Name, r.User, r.Host, r.Profile, r.snapshot(app))
			return nil
		}
		id, err := r.remove(app)
		if err == nil {
			fmt.Printf("%s: retirado para %s/%s/%s; HOME intacto.\nBackup: %s\n", app.Name, r.User, r.Host, r.Profile, id)
		}
		return err
	}
	if disabled, err := r.disabled(app); err != nil {
		return err
	} else if disabled {
		return fmt.Errorf("%s was removed for this context; use orgm-dot restore BACKUP_ID to recover it", app.Name)
	}
	if (cmd == "push" || cmd == "save") && !o.dry {
		id, err := r.save(app)
		if err == nil {
			fmt.Println("Backup:", id)
		}
		return err
	}
	src, paths, err := r.prepared(app)
	if err != nil {
		return err
	}
	defer os.RemoveAll(src)
	if cmd == "diff" || cmd == "push" || cmd == "save" {
		paths, err = r.savePaths(app)
		if err != nil {
			return err
		}
	}
	if len(paths) == 0 {
		return fmt.Errorf("application %s is not selected", app.Name)
	}
	if cmd == "diff" || o.dry {
		changes, err := differences(src, r.Home, paths)
		if err != nil {
			return err
		}
		if o.json {
			return json.NewEncoder(os.Stdout).Encode(changes)
		}
		for _, c := range changes {
			fmt.Printf("%s\t%s\n", c.Code, c.Path)
		}
		if o.dry && (cmd == "push" || cmd == "save") {
			fmt.Println("Push guarda el estado local completo; D pasa a formar parte del repo y A desaparece del snapshot.")
		}
		if o.patch {
			return printPatch(src, r.Home, changes)
		}
		return nil
	}
	var id string
	switch cmd {
	case "pull", "apply":
		id, err = r.apply(app)
	case "push", "save":
		id, err = r.save(app)
	default:
		return fmt.Errorf("unknown command: %s", cmd)
	}
	if err == nil {
		fmt.Println("Backup:", id)
	}
	return err
}

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "orgm-dot:", err)
		os.Exit(1)
	}
}
