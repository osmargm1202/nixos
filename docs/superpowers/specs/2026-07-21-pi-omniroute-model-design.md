# Pi OmniRoute Model Configuration Design

## Goal

Expose OmniRoute's `auto` router as a selectable model in Pi while keeping configuration reproducible through the existing NixOS dotfiles workflow.

## Configuration

Create `dotfiles/config/shared/.pi/agent/models.json` with one custom provider:

- Provider ID: `omniroute`
- API: `openai-completions`
- Base URL: `http://localhost:20128/v1`
- API key source: `$OMNIROUTE_API_KEY`
- Model ID: `auto`
- Context window: 128,000 tokens
- Maximum output: 8,192 tokens
- Input: text and images
- Pi reasoning control: disabled; OmniRoute owns model selection and routing

## Dotfiles Integration

Register `.pi/agent/models.json` in:

- `nixos/common-dotfiles.nix`
- `dotfiles/config/dotfiles.json`

Home Manager will expose the tracked source at `~/.pi/agent/models.json`. Apply the new registered path with `nh os switch`.

## Secret Handling

The JSON file contains only `$OMNIROUTE_API_KEY`, not the token itself. The token must come from the user's environment or secret-management flow. It must not be embedded in a Nix expression because Nix store paths are broadly readable.

## Validation

1. Parse `models.json` as JSON.
2. Run `nh os switch` successfully.
3. Confirm `~/.pi/agent/models.json` resolves to the managed source.
4. Run `pi --list-models omniroute` and confirm provider `omniroute`, model `auto`.

## Scope

No dynamic `/v1/models` synchronization, additional OmniRoute profiles, provider installation, or secret provisioning is included.
