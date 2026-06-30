# Ero-specific shortcuts.

# NixOS rebuild shortcuts.
alias os='nh os switch /home/osmarg/Hobby/nixos/ --hostname ero-i3'
alias osb='nh os build /home/osmarg/Hobby/nixos/ --hostname ero-i3'

function oss --description 'NixOS switch ero-i3, distrobox-aware'
    if set -q CONTAINER_ID; or set -q DISTROBOX_ENTER_PATH; or set -q container; or test -f /.containerenv; or test -f /.dockerenv
        if command -q distrobox-host-exec
            command distrobox-host-exec nh os switch /home/osmarg/Hobby/nixos/ --hostname ero-i3 $argv
            return $status
        end
    end
    command nh os switch /home/osmarg/Hobby/nixos/ --hostname ero-i3 $argv
end

function ossu --description 'NixOS switch+update ero-i3, distrobox-aware'
    if set -q CONTAINER_ID; or set -q DISTROBOX_ENTER_PATH; or set -q container; or test -f /.containerenv; or test -f /.dockerenv
        if command -q distrobox-host-exec
            command distrobox-host-exec nh os switch /home/osmarg/Hobby/nixos/ --hostname ero-i3 --update $argv
            return $status
        end
    end
    command nh os switch /home/osmarg/Hobby/nixos/ --hostname ero-i3 --update $argv
end

alias osbu='nh os build /home/osmarg/Hobby/nixos/ --hostname ero-i3 --update'
