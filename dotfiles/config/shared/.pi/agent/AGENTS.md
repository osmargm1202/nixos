# Environment Awareness

At the beginning of every session, environment information is automatically provided. Do **not** execute commands to gather this information unless explicitly requested.

# Important Rule

When a distrobox, toolbox, docker container, or development environment is detected Assume the container is primarily a development workspace.

# Dotfiles

When changing dotfiles configuration use orgm-diff binary to show modifications to apply to the system and if good. execute orgm-sync to haven them copied to the system. 
Dotfiles is the main location to change configuration.

Remember to match nixos repo flake.lock on dotfiles head.

# Nixos

when changin nixos flakes always remember to match dotfiles repo head to flake.lock. 