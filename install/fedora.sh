install_packages() {
  section "Updating system packages..."
  run_as_root dnf upgrade -y

  local packages=(
    git sudo less net-tools whois bash-completion
    fzf zoxide tmux jq man-db tldr
    vim neovim luarocks
    libyaml
    curl wget
    gh
    kitty-terminfo
  )

  if [ "$IN_CONTAINER" -eq 0 ]; then
    packages+=(@development-tools btop clang llvm rust cargo openssh-server tailscale)
  elif [ "$OMATERM_PROFILE" = "toolchain" ] || [ "$OMATERM_PROFILE" = "full" ]; then
    packages+=(@development-tools clang llvm rust cargo)
  fi

  section "Installing Fedora packages..."
  run_as_root dnf install -y "${packages[@]}"

  # starship (not in Fedora repos)
  if ! command -v starship &>/dev/null; then
    section "Installing starship..."
    if [ "$IN_CONTAINER" -eq 1 ]; then
      mkdir -p "$HOME/.local/bin"
      curl -sS https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$HOME/.local/bin"
    else
      curl -sS https://starship.rs/install.sh | sh -s -- --yes
    fi
  fi

  # eza (not in Fedora repos)
  if ! command -v eza &>/dev/null; then
    section "Installing eza..."
    cargo install eza
  fi

  # Docker (not in Fedora repos, needs Docker's official repo)
  if [ "$IN_CONTAINER" -eq 0 ] && ! command -v docker &>/dev/null; then
    section "Installing Docker..."
    run_as_root dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
    run_as_root dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  fi

  # lazygit (via COPR)
  if ! command -v lazygit &>/dev/null; then
    section "Installing lazygit..."
    run_as_root dnf copr enable -y atim/lazygit
    run_as_root dnf install -y lazygit
  fi

  # lazydocker (not in repos)
  if [ "$IN_CONTAINER" -eq 0 ] && ! command -v lazydocker &>/dev/null; then
    section "Installing lazydocker..."
    curl -fsSL https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
  fi

  # gum (from Charm repo)
  if ! command -v gum &>/dev/null; then
    section "Installing gum..."
    echo '[charm]
name=Charm
baseurl=https://repo.charm.sh/yum/
enabled=1
gpgcheck=1
gpgkey=https://repo.charm.sh/yum/gpg.key' | run_as_root tee /etc/yum.repos.d/charm.repo >/dev/null
    run_as_root dnf install -y gum
  fi

  # mise (not in Fedora repos)
  if ! command -v mise &>/dev/null; then
    section "Installing mise..."
    curl -fsSL https://mise.run | sh
    export PATH="$HOME/.local/bin:$PATH"
  fi
}

install_npm_tools() {
  section "Installing AI coding assistants..."
  if ! command -v opencode &>/dev/null; then
    npm install -g opencode-ai
  fi
  if [ "$IN_CONTAINER" -eq 0 ] && ! command -v claude-code &>/dev/null; then
    npm install -g @anthropic-ai/claude-code
  fi
}

enable_services() {
  if [ "$IN_CONTAINER" -eq 1 ]; then
    section "Skipping services in container..."
    return
  fi

  section "Enabling services..."

  run_as_root systemctl enable docker.service
  run_as_root systemctl start --no-block docker.service
  echo "✓ Docker"

  run_as_root systemctl enable --now sshd.service
  echo "✓ sshd"
}
