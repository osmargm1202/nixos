# Lenovo-specific shortcuts.

# NixOS rebuild shortcuts.
alias os='nh os switch /home/osmarg/Hobby/nixos/ --hostname lenovo-hyprland'
alias osb='nh os build /home/osmarg/Hobby/nixos/ --hostname lenovo-hyprland'
function oss --description 'NixOS switch lenovo-hyprland'
    command nh os switch /home/osmarg/Hobby/nixos/ --hostname lenovo-hyprland $argv
end

function ossu --description 'NixOS switch+update lenovo-hyprland'
    command nh os switch /home/osmarg/Hobby/nixos/ --hostname lenovo-hyprland --update $argv
end
alias osbu='nh os build /home/osmarg/Hobby/nixos/ --hostname lenovo-hyprland --update'
