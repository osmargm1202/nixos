# ORGM-specific shortcuts.
export HELPER_SCALE=1.00

# NixOS rebuild shortcuts.
alias os='nh os switch /home/osmarg/Hobby/nixos/ --hostname orgm'
alias osboot='nh os boot /home/osmarg/Hobby/nixos/ --hostname orgm'
alias osb='nh os build /home/osmarg/Hobby/nixos/ --hostname orgm'

oss() {
  command nh os switch /home/osmarg/Hobby/nixos/ --hostname orgm "$@"
}

ossu() {
  command nh os switch /home/osmarg/Hobby/nixos/ --hostname orgm --update "$@"
}

alias osbu='nh os build /home/osmarg/Hobby/nixos/ --hostname orgm --update'
