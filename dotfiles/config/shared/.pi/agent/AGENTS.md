# Environment Awareness

At the beginning of every session, environment information is automatically provided. Do **not** execute commands to gather this information unless explicitly requested.

# Important Rule

When a distrobox, toolbox, docker container, or development environment is detected Assume the container is primarily a development workspace.

# Dotfiles

Dotfiles is the main location for configuration changes. Existing Home Manager out-of-store symlinks apply source edits live. When registering a new path or changing NixOS/Home Manager modules, run `nh os switch`.

Remember to match the NixOS repository `flake.lock` to the dotfiles repository head.

# NixOS

When changing NixOS flakes, keep the dotfiles repository head aligned with `flake.lock`.