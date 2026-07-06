# Ero-specific shortcuts.

# NixOS rebuild shortcuts.
alias os='nh os switch /home/osmarg/Hobby/nixos/ --hostname ero-i3'
alias osb='nh os build /home/osmarg/Hobby/nixos/ --hostname ero-i3'

function oss --description 'NixOS switch ero-i3'
    command nh os switch /home/osmarg/Hobby/nixos/ --hostname ero-i3 $argv
end

function ossu --description 'NixOS switch+update ero-i3'
    command nh os switch /home/osmarg/Hobby/nixos/ --hostname ero-i3 --update $argv
end

alias osbu='nh os build /home/osmarg/Hobby/nixos/ --hostname ero-i3 --update'
