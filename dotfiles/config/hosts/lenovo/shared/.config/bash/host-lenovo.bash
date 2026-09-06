# Lenovo-specific shortcuts.

# NixOS rebuild shortcuts.
alias os='nh os switch /home/osmarg/Hobby/nixos/ --hostname lenovo-hyprland'
alias osb='nh os build /home/osmarg/Hobby/nixos/ --hostname lenovo-hyprland'

oss() {
  command nh os switch /home/osmarg/Hobby/nixos/ --hostname lenovo-hyprland "$@"
}

ossu() {
  command nh os switch /home/osmarg/Hobby/nixos/ --hostname lenovo-hyprland --update "$@"
}

alias osbu='nh os build /home/osmarg/Hobby/nixos/ --hostname lenovo-hyprland --update'
