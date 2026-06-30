# ORGM-specific shortcuts.
set -gx HELPER_SCALE 1.00

# NixOS rebuild shortcuts.
alias os='nh os switch /home/osmarg/Hobby/nixos/ --hostname orgm-hyprland'
alias osb='nh os build /home/osmarg/Hobby/nixos/ --hostname orgm-hyprland'
function oss --description 'NixOS switch orgm-hyprland, distrobox-aware'
    if set -q CONTAINER_ID; or set -q DISTROBOX_ENTER_PATH; or set -q container; or test -f /.containerenv; or test -f /.dockerenv
        if command -q distrobox-host-exec
            command distrobox-host-exec nh os switch /home/osmarg/Hobby/nixos/ --hostname orgm-hyprland $argv
            return $status
        end
    end
    command nh os switch /home/osmarg/Hobby/nixos/ --hostname orgm-hyprland $argv
end

function ossu --description 'NixOS switch+update orgm-hyprland, distrobox-aware'
    if set -q CONTAINER_ID; or set -q DISTROBOX_ENTER_PATH; or set -q container; or test -f /.containerenv; or test -f /.dockerenv
        if command -q distrobox-host-exec
            command distrobox-host-exec nh os switch /home/osmarg/Hobby/nixos/ --hostname orgm-hyprland --update $argv
            return $status
        end
    end
    command nh os switch /home/osmarg/Hobby/nixos/ --hostname orgm-hyprland --update $argv
end
alias osbu='nh os build /home/osmarg/Hobby/nixos/ --hostname orgm-hyprland --update'
