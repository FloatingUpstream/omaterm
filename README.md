# Omaterm

An omakase headless setup for Arch Linux servers or dev boxes in the spirit of Omarchy by DHH.

## Requirements

- Base Arch Linux installation
- Internet connection
- `sudo` privileges

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/FloatingUpstream/omaterm/master/install.sh | bash
```

For a local Docker workflow, use `container.sh` or build the top-level
`Dockerfile` directly. The installer automatically switches to a container-safe
mode inside Docker and skips host services like Docker, SSH, Tailscale, and
serial console setup.

## What it sets up

- **Shell**: Bash with starship prompt, fzf, eza, zoxide
- **Editors**: Neovim (LazyVim), opencode, claude-code
- **Dev tools**: mise, docker, github-cli, lazygit, lazydocker
- **Networking**: SSH, tailscale
- **Git**: Interactive config for user name/email, helpful aliases

## Container

Build and launch a local Omaterm container from this fork:

```bash
curl -fsSL https://raw.githubusercontent.com/FloatingUpstream/omaterm/feature/devcontainer-support/container.sh | bash
```

Use the heavier toolchain profile:

```bash
curl -fsSL https://raw.githubusercontent.com/FloatingUpstream/omaterm/feature/devcontainer-support/container.sh | bash -s -- --profile toolchain
```

Use Ubuntu instead:

```bash
curl -fsSL https://raw.githubusercontent.com/FloatingUpstream/omaterm/feature/devcontainer-support/container.sh | bash -s -- --base ubuntu
```

For a reusable local shortcut, install `~/bin/omaterm-container`. It keeps a
managed checkout in `~/.local/share/omaterm` and defaults to the `toolchain`
profile:

```bash
omaterm-container
```

Update the managed checkout first:

```bash
omaterm-container --update
```

- Uses the top-level `Dockerfile`
- Defaults to Arch (`archlinux:latest`)
- Defaults to the lighter `default` package profile
- Supports Ubuntu (`ubuntu:24.04`) and Arch (`archlinux:latest`) base images
- `toolchain` adds compiler/build packages that are excluded from the default profile
- Mounts the current host directory into `/workspace`
- Builds the image with your current host UID/GID for better file ownership
- Reuses a named Docker container per workspace so tmux sessions survive detaching and rerunning `./container.sh`
- Use `./container.sh --reset` to rebuild and recreate the container cleanly
- `omaterm-container` stores its managed checkout in `~/.local/share/omaterm`

## Interactive prompts

During installation you'll be asked for:

- Git user name
- Git email address

And you'll be offered to setup:

- Tailscale
- GitHub
- SSH public keys
