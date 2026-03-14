install_packages() {
  local official_pkgs=(
    git sudo less inetutils whois bash-completion
    starship fzf eza zoxide tmux jq gum man-db tldr
    vim neovim luarocks
    mise libyaml
    github-cli lazygit opencode
    kitty-terminfo
  )

  local aur_pkgs=()

  if [ "$IN_CONTAINER" -eq 0 ]; then
    official_pkgs+=(btop base-devel clang llvm rust openssh lazydocker docker docker-buildx docker-compose tailscale)
    aur_pkgs+=(claude-code)
  elif [ "$OMATERM_PROFILE" = "toolchain" ] || [ "$OMATERM_PROFILE" = "full" ]; then
    official_pkgs+=(base-devel clang llvm rust)
  fi

  section "Installing Arch packages..."
  run_as_root pacman -Syu --needed --noconfirm "${official_pkgs[@]}"

  if [ "${#aur_pkgs[@]}" -gt 0 ] && ! command -v yay &>/dev/null; then
    section "Installing yay..."
    local tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$tmpdir/yay"
    (cd "$tmpdir/yay" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"
  fi

  if [ "${#aur_pkgs[@]}" -gt 0 ]; then
    section "Installing AUR packages..."
    yay -S --needed --noconfirm "${aur_pkgs[@]}"
  fi
}

install_npm_tools() {
  :
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
