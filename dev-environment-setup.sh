#!/usr/bin/env bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }
section() { echo -e "\n${CYAN}══ $1 ══${NC}"; }

[[ "$(uname -s)" != "Linux" ]] && error "Linux only."

# Load nvm if available
export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"

# ── Setup functions ───────────────────────────────────────────────────────────

setup_nodejs() {
  section "Node.js global packages"
  if ! command -v npm &>/dev/null; then
    error "npm not found. Run setup.sh first."
  fi
  local packages=(
    typescript
    ts-node
    eslint
    prettier
    nodemon
    concurrently
    serve
  )
  for pkg in "${packages[@]}"; do
    if npm list -g "$pkg" &>/dev/null; then
      success "$pkg already installed"
    else
      info "Installing $pkg..."
      npm install -g "$pkg"
      success "$pkg installed"
    fi
  done
}

setup_python() {
  section "Python environment (uv)"
  if ! command -v uv &>/dev/null; then
    export PATH="$HOME/.local/bin:$PATH"
  fi
  if ! command -v uv &>/dev/null; then
    error "uv not found. Run setup.sh first."
  fi

  info "Installing Python via uv..."
  uv python install 3.13
  success "Python 3.13 installed via uv"

  info "Creating default virtual environment at ~/Developer/python-template..."
  TMPL="$HOME/Developer/python-template"
  mkdir -p "$TMPL"
  if [[ ! -d "$TMPL/.venv" ]]; then
    uv venv "$TMPL/.venv"
  fi

  info "Installing common packages into template venv..."
  uv pip install \
    --python "$TMPL/.venv/bin/python" \
    numpy pandas matplotlib seaborn scikit-learn \
    requests httpx \
    pytest ruff \
    python-dotenv \
    aisuite[anthropic]
  success "Python template environment ready"

  # Write a sample .env template
  if [[ ! -f "$TMPL/.env.example" ]]; then
    cat > "$TMPL/.env.example" <<'EOF'
ANTHROPIC_API_KEY=your_key_here
OPENAI_API_KEY=your_key_here
EOF
    success ".env.example created in ~/Developer/python-template"
  fi
}

setup_ruby() {
  section "Ruby (rbenv)"
  if ! command -v rbenv &>/dev/null; then
    info "Installing rbenv..."
    sudo apt-get install -y -qq rbenv ruby-build
    # Alternatively use the official installer:
    # curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash
    echo 'eval "$(rbenv init -)"' >> "$HOME/.bashrc"
    eval "$(rbenv init -)"
    success "rbenv installed"
  else
    success "rbenv already installed"
  fi

  RUBY_VERSION="3.3.0"
  if rbenv versions | grep -q "$RUBY_VERSION"; then
    success "Ruby $RUBY_VERSION already installed"
  else
    info "Installing Ruby $RUBY_VERSION (may take a while)..."
    rbenv install "$RUBY_VERSION"
    rbenv global "$RUBY_VERSION"
    success "Ruby $RUBY_VERSION installed"
  fi
  gem install bundler --quiet && success "Bundler installed"
}

setup_git() {
  section "Git aliases and config"
  git config --global alias.st  status
  git config --global alias.co  checkout
  git config --global alias.br  branch
  git config --global alias.lg  "log --oneline --graph --decorate --all"
  git config --global alias.undo "reset HEAD~1 --mixed"
  git config --global core.editor "nano"

  GITIGNORE="$HOME/.gitignore_global"
  cat > "$GITIGNORE" <<'EOF'
.DS_Store
.env
.env.local
.env.*.local
*.log
*.swp
*.swo
__pycache__/
*.pyc
.venv/
node_modules/
dist/
build/
.idea/
.vscode/
EOF
  git config --global core.excludesfile "$GITIGNORE"
  success "Git aliases and global .gitignore configured"
}

setup_docker() {
  section "Docker"
  if command -v docker &>/dev/null; then
    success "Docker already installed ($(docker --version))"
  else
    info "Installing Docker..."
    ARCH=$(dpkg --print-architecture)
    DISTRO=$(lsb_release -cs)
    curl -fsSL https://download.docker.com/linux/debian/gpg \
      | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
https://download.docker.com/linux/debian ${DISTRO} stable" \
      | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt-get update -qq
    sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
    sudo usermod -aG docker "$USER"
    success "Docker installed — re-login for group membership to take effect"
  fi

  DOCKER_TMPL="$HOME/Developer/docker-template"
  mkdir -p "$DOCKER_TMPL"
  if [[ ! -f "$DOCKER_TMPL/docker-compose.yml" ]]; then
    cat > "$DOCKER_TMPL/docker-compose.yml" <<'EOF'
services:
  app:
    build: .
    ports:
      - "3000:3000"
    volumes:
      - .:/app
    environment:
      - NODE_ENV=development
EOF
    cat > "$DOCKER_TMPL/Dockerfile" <<'EOF'
FROM node:22-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
EXPOSE 3000
CMD ["node", "index.js"]
EOF
    success "Docker template created in ~/Developer/docker-template"
  fi
}

setup_vscode() {
  section "VS Code"
  ARCH=$(dpkg --print-architecture)

  if command -v code &>/dev/null; then
    success "VS Code already installed"
  else
    info "Installing VS Code..."
    TMP=$(mktemp -d)

    if [[ "$ARCH" == "arm64" ]]; then
      VS_URL="https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-arm64"
    else
      VS_URL="https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"
    fi

    wget -q -O "$TMP/vscode.deb" "$VS_URL"
    sudo apt-get install -y -qq "$TMP/vscode.deb"
    rm -rf "$TMP"
    success "VS Code installed"
  fi

  if command -v code &>/dev/null; then
    info "Installing VS Code extensions..."
    local extensions=(
      "anthropics.claude-code"
      "ms-python.python"
      "ms-python.vscode-pylance"
      "dbaeumer.vscode-eslint"
      "esbenp.prettier-vscode"
      "ms-vscode.vscode-typescript-next"
      "bradlc.vscode-tailwindcss"
      "eamodio.gitlens"
      "ms-azuretools.vscode-docker"
      "redhat.vscode-yaml"
    )
    for ext in "${extensions[@]}"; do
      code --install-extension "$ext" --force &>/dev/null && success "$ext" || warn "Failed: $ext"
    done
  fi
}

setup_shell() {
  section "Shell aliases and functions"
  SHELL_RC="$HOME/.bashrc"
  [[ "$SHELL" == */zsh ]] && SHELL_RC="$HOME/.zshrc"

  MARKER="# dev-environment-setup aliases"
  if grep -qF "$MARKER" "$SHELL_RC" 2>/dev/null; then
    warn "Shell aliases already added to $SHELL_RC — skipping"
    return
  fi

  cat >> "$SHELL_RC" <<'ALIASES'

# dev-environment-setup aliases
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias df='df -h'
alias du='du -h'

# Git shortcuts
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias glog='git log --oneline --graph --decorate --all'

# Dev shortcuts
alias py='python3'
alias dev='cd ~/Developer'

# Show PATH entries one per line
alias path='echo $PATH | tr ":" "\n"'

# Quick HTTP server
serve() { python3 -m http.server "${1:-8000}"; }

# Create dir and cd into it
mkcd() { mkdir -p "$1" && cd "$1"; }

# Extract any archive
extract() {
  case "$1" in
    *.tar.bz2) tar xjf "$1";;
    *.tar.gz)  tar xzf "$1";;
    *.tar.xz)  tar xJf "$1";;
    *.zip)     unzip "$1";;
    *.gz)      gunzip "$1";;
    *.bz2)     bunzip2 "$1";;
    *.7z)      7z x "$1";;
    *)         echo "Unknown format: $1";;
  esac
}
ALIASES

  success "Shell aliases added to $SHELL_RC"
}

# ── Interactive menu ──────────────────────────────────────────────────────────
show_menu() {
  echo ""
  echo "╔════════════════════════════════════════╗"
  echo "║   Dev Environment Setup — Debian      ║"
  echo "╚════════════════════════════════════════╝"
  echo ""
  echo "  1) Node.js global packages"
  echo "  2) Python (uv + template venv)"
  echo "  3) Ruby (rbenv)"
  echo "  4) Git aliases & global .gitignore"
  echo "  5) Docker"
  echo "  6) VS Code + extensions"
  echo "  7) Shell aliases & functions"
  echo "  a) All of the above"
  echo "  q) Quit"
  echo ""
  read -rp "Choose (comma-separated, e.g. 1,4,7): " choice
  echo ""

  [[ "$choice" == "q" ]] && { info "Bye!"; exit 0; }

  IFS=',' read -ra CHOICES <<< "$choice"
  for c in "${CHOICES[@]}"; do
    c="${c// /}"
    case "$c" in
      1|node)   setup_nodejs ;;
      2|python) setup_python ;;
      3|ruby)   setup_ruby   ;;
      4|git)    setup_git    ;;
      5|docker) setup_docker ;;
      6|vscode) setup_vscode ;;
      7|shell)  setup_shell  ;;
      a|all)
        setup_nodejs
        setup_python
        setup_ruby
        setup_git
        setup_docker
        setup_vscode
        setup_shell
        ;;
      *) warn "Unknown option: $c" ;;
    esac
  done

  echo ""
  success "Done! Run: source ~/.bashrc"
}

show_menu
