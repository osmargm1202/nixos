# ORGM-specific shortcuts.
export HELPER_SCALE=1.00

# NixOS rebuild shortcuts.
alias os='nh os switch /home/osmarg/Hobby/nixos/ --hostname orgm-hyprland'
alias osb='nh os build /home/osmarg/Hobby/nixos/ --hostname orgm-hyprland'

oss() {
  command nh os switch /home/osmarg/Hobby/nixos/ --hostname orgm-hyprland "$@"
}

ossu() {
  command nh os switch /home/osmarg/Hobby/nixos/ --hostname orgm-hyprland --update "$@"
}

alias osbu='nh os build /home/osmarg/Hobby/nixos/ --hostname orgm-hyprland --update'
