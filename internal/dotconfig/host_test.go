package dotconfig

import "testing"

func TestResolveHostUsesExplicitHost(t *testing.T) {
	rt := Runtime{Config: Config{Hosts: map[string]PathList{
		"lenovo": {Paths: []string{".config/fish"}},
		"orgm":   {Paths: []string{".config/fish"}},
	}}}

	host, err := rt.ResolveHost("orgm", func() (string, error) { return "lenovo", nil })
	if err != nil {
		t.Fatal(err)
	}
	if host != "orgm" {
		t.Fatalf("host = %q, want orgm", host)
	}
}

func TestResolveHostDefaultsToHostname(t *testing.T) {
	rt := Runtime{Config: Config{Hosts: map[string]PathList{
		"lenovo": {Paths: []string{".config/fish"}},
	}}}

	host, err := rt.ResolveHost("", func() (string, error) { return "lenovo", nil })
	if err != nil {
		t.Fatal(err)
	}
	if host != "lenovo" {
		t.Fatalf("host = %q, want lenovo", host)
	}
}

func TestResolveHostRejectsUnknownHostname(t *testing.T) {
	rt := Runtime{Config: Config{Hosts: map[string]PathList{
		"lenovo": {Paths: []string{".config/fish"}},
	}}}

	_, err := rt.ResolveHost("", func() (string, error) { return "container", nil })
	if err == nil {
		t.Fatal("expected unknown hostname error")
	}
}
