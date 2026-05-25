#!/usr/bin/env bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# ── Guard: Debian/Ubuntu only ─────────────────────────────────────────────────
if [[ "$(uname -s)" != "Linux" ]]; then
  error "This script is for Linux (Debian/Ubuntu). Use the macbook repo on macOS."
fi
if ! command -v apt-get &>/dev/null; then
  error "This script requires apt (Debian/Ubuntu). Detected non-apt system."
fi

ARCH=$(dpkg --print-architecture)  # amd64, arm64, armhf …

echo ""
echo "╔════════════════════════════════════════╗"
echo "║      Debian Development Setup         ║"
echo "╚════════════════════════════════════════╝"
echo ""
info "Architecture: $ARCH"
info "Distro: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')"
echo ""
read -rp "This will install dev tools system-wide. Continue? [y/N] " confirm
[[ "${confirm,,}" == "y" ]] || { info "Aborted."; exit 0; }
echo ""

# ── APT bootstrap ─────────────────────────────────────────────────────────────
info "Updating apt and installing base packages..."
sudo apt-get update -qq
sudo apt-get install -y -qq \
  build-essential \
  curl \
  wget \
  git \
  gnupg \
  ca-certificates \
  lsb-release \
  software-properties-common \
  unzip \
  zip \
  jq \
  tree \
  htop \
  ffmpeg \
  graphviz \
  sqlite3 \
  xclip \
  xsel
success "Base packages installed"

# ── Git ───────────────────────────────────────────────────────────────────────
if ! git config --global user.name &>/dev/null || [[ -z "$(git config --global user.name)" ]]; then
  echo ""
  info "Configure git globals (leave blank to skip):"
  read -rp "  Git name:  " git_name
  read -rp "  Git email: " git_email
  [[ -n "$git_name" ]]  && git config --global user.name  "$git_name"
  [[ -n "$git_email" ]] && git config --global user.email "$git_email"
  git config --global init.defaultBranch main
  git config --global pull.rebase false
  success "Git configured"
else
  success "Git already configured ($(git config --global user.name))"
fi

# ── GitHub CLI ────────────────────────────────────────────────────────────────
if ! command -v gh &>/dev/null; then
  info "Installing GitHub CLI..."
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
  sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y -qq gh
  success "GitHub CLI installed ($(gh --version | head -1))"
else
  success "GitHub CLI already installed ($(gh --version | head -1))"
fi

# ── nvm + Node.js ─────────────────────────────────────────────────────────────
NVM_VERSION="0.40.3"
NODE_VERSION="22"

if [[ ! -d "$HOME/.nvm" ]]; then
  info "Installing nvm ${NVM_VERSION}..."
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh" | bash
  success "nvm installed"
else
  success "nvm already installed"
fi

# Load nvm for the rest of this script
export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"

if ! node --version &>/dev/null; then
  info "Installing Node.js ${NODE_VERSION} LTS..."
  nvm install "$NODE_VERSION"
  nvm alias default "$NODE_VERSION"
  nvm use default
  success "Node.js $(node --version) installed"
else
  success "Node.js already installed ($(node --version))"
fi

# ── Claude Code CLI ───────────────────────────────────────────────────────────
if ! command -v claude &>/dev/null; then
  info "Installing Claude Code CLI..."
  npm install -g @anthropic-ai/claude-code
  success "Claude Code installed"
else
  success "Claude Code already installed"
fi

# ── uv (Python package manager) ───────────────────────────────────────────────
if ! command -v uv &>/dev/null; then
  info "Installing uv (Python package manager)..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  # Add uv to PATH for this session
  export PATH="$HOME/.local/bin:$PATH"
  success "uv installed ($(uv --version 2>/dev/null || echo 'restart shell to verify'))"
else
  success "uv already installed ($(uv --version))"
fi

# ── Deno ──────────────────────────────────────────────────────────────────────
if ! command -v deno &>/dev/null; then
  info "Installing Deno..."
  curl -fsSL https://deno.land/install.sh | sh
  export DENO_INSTALL="$HOME/.deno"
  export PATH="$DENO_INSTALL/bin:$PATH"
  success "Deno installed ($(deno --version | head -1))"
else
  success "Deno already installed ($(deno --version | head -1))"
fi

# ── Developer directory ───────────────────────────────────────────────────────
DEVDIR="$HOME/Developer"
if [[ ! -d "$DEVDIR" ]]; then
  info "Creating ~/Developer directory structure..."
  mkdir -p "$DEVDIR"/{projects,learning,scripts,python-template,docker-template}
  success "~/Developer created"
else
  success "~/Developer already exists"
fi

# ── Shell profile updates ─────────────────────────────────────────────────────
SHELL_RC="$HOME/.bashrc"
[[ "$SHELL" == */zsh ]] && SHELL_RC="$HOME/.zshrc"

add_to_profile() {
  local marker="$1"
  local block="$2"
  if ! grep -qF "$marker" "$SHELL_RC" 2>/dev/null; then
    echo "" >> "$SHELL_RC"
    echo "# $marker" >> "$SHELL_RC"
    echo "$block" >> "$SHELL_RC"
  fi
}

add_to_profile "uv PATH" 'export PATH="$HOME/.local/bin:$PATH"'
add_to_profile "deno PATH" 'export DENO_INSTALL="$HOME/.deno"; export PATH="$DENO_INSTALL/bin:$PATH"'
add_to_profile "nvm setup" 'export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'

success "Shell profile updated ($SHELL_RC)"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "╔════════════════════════════════════════╗"
echo "║          Setup complete! ✓             ║"
echo "╚════════════════════════════════════════╝"
echo ""
info "Next steps:"
echo "  1. Restart your shell:  source $SHELL_RC"
echo "  2. Authenticate GitHub: gh auth login"
echo "  3. Generate SSH key:    ssh-keygen -t ed25519 -C \"your@email.com\""
echo "  4. Run optional setup:  ./dev-environment-setup.sh"
echo ""
info "Installed tools:"
echo "  • Git        $(git --version)"
echo "  • Node.js    $(node --version 2>/dev/null || echo '(restart shell)')"
echo "  • GitHub CLI $(gh --version | head -1)"
echo "  • FFmpeg     $(ffmpeg -version 2>&1 | head -1 | awk '{print $3}')"
echo "  • Graphviz   $(dot -V 2>&1 | awk '{print $5}')"
echo ""
