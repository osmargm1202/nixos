# ORGM-specific shortcuts.
set -gx HELPER_SCALE 1.00

# NixOS rebuild shortcuts.
alias os='nh os switch /home/osmarg/Hobby/nixos/ --hostname orgm-hyprland'
alias osb='nh os build /home/osmarg/Hobby/nixos/ --hostname orgm-hyprland'
function oss --description 'NixOS switch orgm-hyprland'
    command nh os switch /home/osmarg/Hobby/nixos/ --hostname orgm-hyprland $argv
end

function ossu --description 'NixOS switch+update orgm-hyprland'
    command nh os switch /home/osmarg/Hobby/nixos/ --hostname orgm-hyprland --update $argv
end
alias osbu='nh os build /home/osmarg/Hobby/nixos/ --hostname orgm-hyprland --update'
