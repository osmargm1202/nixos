function sshgo --description 'Pick a host from ~/.config/orgm-hosts/hosts.conf and ssh into it via Tailscale'
    set -l hosts_file "$HOME/.config/orgm-hosts/hosts.conf"

    if not test -s "$hosts_file"
        echo "sshgo: no hosts in $hosts_file" >&2
        return 1
    end

    if not type -q tailscale
        echo "sshgo: tailscale not installed" >&2
        return 1
    end

    set -l status_json (tailscale status --json 2>&1)
    if test $status -ne 0
        echo "sshgo: tailscale status failed:" >&2
        echo "$status_json" >&2
        return 1
    end

    set -l rows
    while read -l line
        set -l parts (string split ' ' -- $line)
        if test (count $parts) -lt 2
            continue
        end
        set -l host $parts[1]
        set -l user $parts[2]

        set -l peer (echo $status_json | jq -r --arg h "$host" '
            .Peer[] | select(.HostName | ascii_downcase == ($h | ascii_downcase))
        ')

        set -l label
        if test -z "$peer"
            set label "$host $user ❓ unknown (not in tailnet)"
        else
            set -l online (echo $peer | jq -r '.Online')
            set -l last_seen (echo $peer | jq -r '.LastSeen')
            if test "$online" = "true"
                set label "$host $user 🟢 online"
            else
                set label "$host $user 🔴 offline (last seen $last_seen)"
            end
        end
        set -a rows $label
    end < "$hosts_file"

    set -l choice (printf '%s\n' $rows | gum choose)
    if test -z "$choice"
        return 0
    end

    set -l chosen_parts (string split ' ' -- $choice)
    set -l chosen_host $chosen_parts[1]
    set -l chosen_user $chosen_parts[2]

    # Connect by Tailscale IP: works without MagicDNS/accept-dns, which we
    # keep disabled so the system uses its own DNS resolvers.
    set -l chosen_ip (echo $status_json | jq -r --arg h "$chosen_host" '
        .Peer[] | select(.HostName | ascii_downcase == ($h | ascii_downcase)) | .TailscaleIPs[0] // empty
    ')

    if test -n "$chosen_ip"
        exec ssh "$chosen_user@$chosen_ip"
    end
    exec ssh "$chosen_user@$chosen_host"
end
