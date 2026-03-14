install_packages() {
  section "Updating system packages..."
  run_as_root apt-get update
  run_as_root apt-get upgrade -y

  local packages=(
    git sudo less net-tools whois bash-completion
    fzf eza zoxide tmux jq man-db
    vim neovim luarocks
    libyaml-0-2
    curl wget gpg
    kitty-terminfo
  )

  if [ "$IN_CONTAINER" -eq 0 ]; then
    packages+=(build-essential libssl-dev btop clang llvm rustc openssh-server docker.io docker-buildx docker-compose)
  elif [ "$OMATERM_PROFILE" = "toolchain" ] || [ "$OMATERM_PROFILE" = "full" ]; then
    packages+=(build-essential libssl-dev clang llvm rustc)
  fi

  section "Installing Debian packages..."
  run_as_root apt-get install -y "${packages[@]}"

  # tldr: Debian Trixie+ replaced tldr with tealdeer
  if apt-cache show tealdeer &>/dev/null; then
    run_as_root apt-get install -y tealdeer
  else
    run_as_root apt-get install -y tldr
  fi

  # github-cli (not in Debian/Ubuntu repos)
  if ! command -v gh &>/dev/null; then
    section "Installing GitHub CLI..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | run_as_root dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    printf 'deb [arch=%s signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\n' "$(dpkg --print-architecture)" | run_as_root tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    run_as_root apt-get update
    run_as_root apt-get install -y gh
  fi

  # tailscale (not in Debian/Ubuntu repos)
  if [ "$IN_CONTAINER" -eq 0 ] && ! command -v tailscale &>/dev/null; then
    section "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
  fi

  # starship (not in Debian/Ubuntu repos)
  if ! command -v starship &>/dev/null; then
    section "Installing starship..."
    if [ "$IN_CONTAINER" -eq 1 ]; then
      mkdir -p "$HOME/.local/bin"
      curl -sS https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$HOME/.local/bin"
    else
      curl -sS https://starship.rs/install.sh | sh -s -- --yes
    fi
  fi

  # lazygit (not in Ubuntu repos)
  if ! command -v lazygit &>/dev/null; then
    section "Installing lazygit..."
    local LAZYGIT_VERSION
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": *"v\K[^"]*')
    curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
    tar xf /tmp/lazygit.tar.gz -C /tmp lazygit
    run_as_root install /tmp/lazygit /usr/local/bin/
    rm -f /tmp/lazygit.tar.gz /tmp/lazygit
  fi

  # lazydocker (not in Ubuntu repos)
  if [ "$IN_CONTAINER" -eq 0 ] && ! command -v lazydocker &>/dev/null; then
    section "Installing lazydocker..."
    curl -fsSL https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
  fi

  # gum (from Charm apt repo)
  if ! command -v gum &>/dev/null; then
    section "Installing gum..."
    run_as_root mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.charm.sh/apt/gpg.key | run_as_root gpg --dearmor -o /etc/apt/keyrings/charm.gpg
    printf 'deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *\n' | run_as_root tee /etc/apt/sources.list.d/charm.list >/dev/null
    run_as_root apt-get update
    run_as_root apt-get install -y gum
  fi

  # mise (not in Ubuntu repos)
  if ! command -v mise &>/dev/null; then
    section "Installing mise..."
    curl -fsSL https://mise.run | sh 2>/dev/null
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

  run_as_root systemctl enable --now ssh.service
  echo "✓ sshd"
}
