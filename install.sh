#!/usr/bin/env bash
set -euo pipefail

is_truthy() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

detect_container() {
  if is_truthy "${OMATERM_CONTAINER:-}"; then
    return 0
  fi

  if [ -f /.dockerenv ]; then
    return 0
  fi

  grep -qaE '(docker|containerd|kubepods|lxc|podman)' /proc/1/cgroup 2>/dev/null
}

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

IN_CONTAINER=0
if detect_container; then
  IN_CONTAINER=1
fi

OMATERM_REPO="${OMATERM_REPO:-https://github.com/FloatingUpstream/omaterm.git}"
OMATERM_INSTALL_URL="${OMATERM_INSTALL_URL:-https://raw.githubusercontent.com/FloatingUpstream/omaterm/master/install.sh}"
OMADOTS_REPO="${OMADOTS_REPO:-https://github.com/FloatingUpstream/omadots.git}"
OMADOTS_INSTALL_URL="${OMADOTS_INSTALL_URL:-https://raw.githubusercontent.com/FloatingUpstream/omadots/master/install.sh}"

NONINTERACTIVE=0
if is_truthy "${OMATERM_NONINTERACTIVE:-}" || [ ! -t 0 ]; then
  NONINTERACTIVE=1
fi

# Common functions for Omaterm installation
show_banner() {
  clear 2>/dev/null || true
  echo
  echo " ▄██████▄    ▄▄▄▄███▄▄▄▄      ▄████████     ███        ▄████████    ▄████████   ▄▄▄▄███▄▄▄▄  
███    ███ ▄██▀▀▀███▀▀▀██▄   ███    ███ ▀█████████▄   ███    ███   ███    ███ ▄██▀▀▀███▀▀▀██▄
███    ███ ███   ███   ███   ███    ███    ▀███▀▀██   ███    █▀    ███    ███ ███   ███   ███
███    ███ ███   ███   ███   ███    ███     ███   ▀  ▄███▄▄▄      ▄███▄▄▄▄██▀ ███   ███   ███
███    ███ ███   ███   ███ ▀███████████     ███     ▀▀███▀▀▀     ▀▀███▀▀▀▀▀   ███   ███   ███
███    ███ ███   ███   ███   ███    ███     ███       ███    █▄  ▀███████████ ███   ███   ███
███    ███ ███   ███   ███   ███    ███     ███       ███    ███   ███    ███ ███   ███   ███
 ▀██████▀   ▀█   ███   █▀    ███    █▀     ▄████▀     ██████████   ███    ███  ▀█   ███   █▀ 
                                                                   ███    ███                "
}

section() {
  echo -e "\n==> $1"
}

install_omadots() {
  if [ "$IN_CONTAINER" -eq 1 ]; then
    install_omadots_container
    return
  fi

  curl -fsSL "$OMADOTS_INSTALL_URL" | bash
}

install_omadots_container() {
  local omadots_dir

  section "Installing Omadots base config..."
  omadots_dir="$(mktemp -d)"
  git clone --depth 1 "$OMADOTS_REPO" "$omadots_dir"

  mkdir -p "$HOME/.config"
  rm -rf "$HOME/.config/nvim"
  git clone --depth 1 https://github.com/LazyVim/starter "$HOME/.config/nvim"
  rm -rf "$HOME/.config/nvim/.git"

  cp -Rf "$omadots_dir/config/." "$HOME/.config/"

  case "$(basename "${SHELL:-bash}")" in
    zsh)
      cat >"$HOME/.zshrc" <<'EOF'
source ~/.config/shell/all
source ~/.config/shell/zoptions
EOF
      printf '. ~/.zshrc\n' >"$HOME/.zprofile"
      echo "✓ Zsh"
      ;;
    *)
      printf 'source ~/.config/shell/all\n' >"$HOME/.bashrc"
      printf '. ~/.bashrc\n' >"$HOME/.bash_profile"
      ln -snf "$HOME/.config/shell/inputrc" "$HOME/.inputrc"
      echo "✓ Bash"
      ;;
  esac

  rm -rf "$omadots_dir"
}

install_configs() {
  section "Installing configs..."
  mkdir -p "$HOME/.config"
  cp -Rf "$INSTALLER_DIR/config/"* "$HOME/.config/"
  echo "✓ Neovim"
  echo "✓ Starship"

  if ! grep -q "if \[\[ -z \$TMUX \]\]" "$HOME/.bashrc" 2>/dev/null; then
    cat >>"$HOME/.bashrc" <<'EOF'
if [[ -z $TMUX ]]; then
  t
fi
EOF
    echo "✓ Tmux auto-start"
  fi
}

install_bins() {
  section "Installing bins..."
  mkdir -p "$HOME/.local/bin"
  cp -Rf "$INSTALLER_DIR/bin/"* "$HOME/.local/bin/"
  chmod +x "$HOME/.local/bin/"*
  echo "✓ omaterm-ssh"
  echo "✓ omaterm-theme"
  echo "✓ omaterm-refresh"
}

install_mise_tools() {
  section "Installing Ruby + Node..."
  eval "$(mise activate bash)" 2>/dev/null || true
  mise use -g node
  mise use -g ruby
  export PATH="$HOME/.local/share/mise/shims:$PATH"
}

setup_docker_group() {
  if [ "$IN_CONTAINER" -eq 1 ]; then
    return
  fi

  if ! groups | grep -q docker; then
    if command -v usermod &>/dev/null; then
      run_as_root usermod -aG docker "$USER"
    else
      run_as_root adduser "$USER" docker
    fi
  fi
}

interactive_setup() {
  if [ "$NONINTERACTIVE" -eq 1 ]; then
    section "Skipping interactive setup..."
    return
  fi

  section "Interactive setup..."

  if ! gh auth status &>/dev/null; then
    echo
    if gum confirm "Authenticate with GitHub?" </dev/tty; then
      gh auth login
    fi
  fi

  if [ "$IN_CONTAINER" -eq 0 ] && ! tailscale status &>/dev/null; then
    echo
    if gum confirm "Connect to Tailscale network?" </dev/tty; then
      echo "This might take a minute..."
      run_as_root systemctl enable --now tailscaled.service
      run_as_root tailscale up --ssh --accept-routes
    fi
  fi

  if [ "$IN_CONTAINER" -eq 0 ] && grep -qi proxmox /sys/class/dmi/id/product_name 2>/dev/null && [ -e /dev/ttyS0 ]; then
    if ! systemctl is-enabled serial-getty@ttyS0.service &>/dev/null; then
      echo
      if gum confirm "Proxmox VM detected with serial port. Enable serial console?" </dev/tty; then
        run_as_root systemctl enable serial-getty@ttyS0.service
        run_as_root systemctl start serial-getty@ttyS0.service
        echo "✓ Serial console enabled on ttyS0"
      fi
    fi
  fi
}

finish() {
  section "Finished!"
  if [ "$IN_CONTAINER" -eq 1 ]; then
    echo "Omaterm is ready for container use"
  else
    echo "Now logout and back in for everything to take effect"
  fi
}

resolve_installer_dir() {
  local script_dir

  if [ -n "${OMATERM_INSTALLER_DIR:-}" ]; then
    INSTALLER_DIR="$OMATERM_INSTALLER_DIR"
    CLEANUP_INSTALLER_DIR=0
    return
  fi

  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [ -d "$script_dir/install" ] && [ -d "$script_dir/config" ] && [ -d "$script_dir/bin" ]; then
    INSTALLER_DIR="$script_dir"
    CLEANUP_INSTALLER_DIR=0
    return
  fi

  INSTALLER_DIR="$(mktemp -d)"
  CLEANUP_INSTALLER_DIR=1
  git clone --depth 1 "$OMATERM_REPO" "$INSTALLER_DIR"
}

cleanup() {
  if [ "${CLEANUP_INSTALLER_DIR:-0}" -eq 1 ]; then
    rm -rf "$INSTALLER_DIR"
  fi
}

run_installation() {
  # OS-specific package installation
  install_packages

  # Omadots
  install_omadots

  # Configs and bins
  install_configs
  install_bins

  # Mise tooling
  install_mise_tools

  # OS-specific tools that need npm (installed after mise provides node)
  install_npm_tools

  # OS-specific service enabling
  enable_services

  # Setup Docker group
  setup_docker_group

  # Interactive setup
  interactive_setup

  # Done!
  finish
}

# Getting started
show_banner
section "Installing Omaterm..."

# Ensure correct git is installed
if ! command -v git &>/dev/null; then
  if [ -f /etc/arch-release ]; then
    run_as_root pacman -Sy --noconfirm git
  elif [ -f /etc/debian_version ]; then
    run_as_root apt-get update && run_as_root apt-get install -y git
  elif [ -f /etc/fedora-release ]; then
    run_as_root dnf install -y git
  fi
fi

resolve_installer_dir
trap cleanup EXIT

# OS detection and dispatch
if [ -f /etc/arch-release ]; then
  source "$INSTALLER_DIR/install/arch.sh"
elif [ -f /etc/debian_version ]; then
  source "$INSTALLER_DIR/install/debian.sh"
elif [ -f /etc/fedora-release ]; then
  source "$INSTALLER_DIR/install/fedora.sh"
else
  echo "Error: Unsupported operating system"
  echo "Omaterm supports Arch Linux, Debian/Ubuntu, and Fedora"
  exit 1
fi

run_installation
