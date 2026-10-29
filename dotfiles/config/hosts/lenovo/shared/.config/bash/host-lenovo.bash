# Lenovo-specific shortcuts.

# NixOS rebuild shortcuts.
alias os='nh os switch /home/osmarg/Hobby/nixos/ --hostname lenovo-server'
alias osboot='nh os boot /home/osmarg/Hobby/nixos/ --hostname lenovo-server'
alias osb='nh os build /home/osmarg/Hobby/nixos/ --hostname lenovo-server'

oss() {
  command nh os switch /home/osmarg/Hobby/nixos/ --hostname lenovo-server "$@"
}

ossu() {
  command nh os switch /home/osmarg/Hobby/nixos/ --hostname lenovo-server --update "$@"
}

alias osbu='nh os build /home/osmarg/Hobby/nixos/ --hostname lenovo-server --update'
