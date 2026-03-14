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
curl -fsSL https://raw.githubusercontent.com/FloatingUpstream/omaterm/master/container.sh | bash
```

Use Arch instead of Ubuntu:

```bash
curl -fsSL https://raw.githubusercontent.com/FloatingUpstream/omaterm/master/container.sh | bash -s -- --base arch
```

Use Ubuntu instead:

```bash
curl -fsSL https://raw.githubusercontent.com/FloatingUpstream/omaterm/master/container.sh | bash -s -- --base ubuntu
```

- Uses the top-level `Dockerfile`
- Defaults to Arch (`archlinux:latest`)
- Supports Ubuntu (`ubuntu:24.04`) and Arch (`archlinux:latest`) base images
- Mounts the current host directory into `/workspace`
- Builds the image with your current host UID/GID for better file ownership

## Interactive prompts

During installation you'll be asked for:

- Git user name
- Git email address

And you'll be offered to setup:

- Tailscale
- GitHub
- SSH public keys
