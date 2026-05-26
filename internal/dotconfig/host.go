package dotconfig

import (
	"fmt"
	"os"
	"strings"
)

type HostnameFunc func() (string, error)

func OSHostname() (string, error) {
	return os.Hostname()
}

func (r Runtime) ResolveHost(explicit string, hostname HostnameFunc) (string, error) {
	host := strings.TrimSpace(explicit)
	if host == "" {
		if hostname == nil {
			hostname = OSHostname
		}
		name, err := hostname()
		if err != nil {
			return "", fmt.Errorf("detect hostname: %w", err)
		}
		host = strings.TrimSpace(name)
	}
	if host == "" {
		return "", fmt.Errorf("host is empty; use --host HOST")
	}
	if _, ok := r.Config.Hosts[host]; !ok {
		return "", fmt.Errorf("host %q not found in config; use --host HOST", host)
	}
	return host, nil
}
