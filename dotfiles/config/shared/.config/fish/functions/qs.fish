function qs --wraps quickshell --description 'Run quickshell on host from distrobox, or directly on host'
    if set -q CONTAINER_ID; or set -q DISTROBOX_ENTER_PATH; or set -q container; or test -f /.containerenv; or test -f /.dockerenv
        if command -q distrobox-host-exec
            command distrobox-host-exec quickshell $argv
            return $status
        end
    end

    command quickshell $argv
end
