# Ero-specific shortcuts.

# NixOS rebuild shortcuts.
alias os='nh os switch /home/osmarg/Hobby/nixos/ --hostname ero-i3'
alias osb='nh os build /home/osmarg/Hobby/nixos/ --hostname ero-i3'

oss() {
  command nh os switch /home/osmarg/Hobby/nixos/ --hostname ero-i3 "$@"
}

ossu() {
  command nh os switch /home/osmarg/Hobby/nixos/ --hostname ero-i3 --update "$@"
}

alias osbu='nh os build /home/osmarg/Hobby/nixos/ --hostname ero-i3 --update'
