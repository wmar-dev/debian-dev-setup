# Debian Development Setup

Automates setting up a fresh Debian (or Ubuntu) machine with dev tools and a productive shell environment. Mirrors the [macbook](https://github.com/wmar-dev/macbook) repo for Linux.

## Quick start

```bash
git clone https://github.com/wmar-dev/linux-dev-setup.git
cd linux-dev-setup
chmod +x setup.sh dev-environment-setup.sh
./setup.sh
```

Then restart your shell and run the optional setup:

```bash
./dev-environment-setup.sh
```

---

## `setup.sh` — Core installs

Installs the essentials system-wide using `apt` plus direct installers where needed.

| Tool | How |
|------|-----|
| build-essential, curl, wget, git | apt |
| ffmpeg, graphviz, sqlite3 | apt |
| GitHub CLI (`gh`) | official apt repo |
| nvm + Node.js 22 LTS | nvm installer |
| Claude Code CLI | `npm install -g @anthropic-ai/claude-code` |
| uv (Python package manager) | astral.sh installer |
| Deno | deno.land installer |

Also:
- Prompts to configure `git config --global user.name/email`
- Creates `~/Developer/{projects,learning,scripts,python-template,docker-template}`
- Adds nvm, uv, and Deno to your shell profile (`.bashrc` / `.zshrc`)

---

## `dev-environment-setup.sh` — Optional environments

Interactive menu — run any subset:

| Option | What it does |
|--------|-------------|
| **1 Node.js** | Installs TypeScript, ESLint, Prettier, ts-node, nodemon globally |
| **2 Python** | Installs Python 3.13 via uv; creates `~/Developer/python-template/.venv` with common data science + AI packages |
| **3 Ruby** | Installs rbenv, Ruby 3.3, Bundler |
| **4 Git** | Adds useful aliases (`st`, `co`, `lg`, `undo`), sets global `.gitignore` |
| **5 Docker** | Installs Docker CE from official repo; creates docker-compose template |
| **6 VS Code** | Downloads VS Code `.deb` (arm64 or x64 auto-detected); installs Claude Code, Python, ESLint, GitLens extensions |
| **7 Shell** | Adds aliases (`ll`, `gs`, `..`), helper functions (`serve`, `mkcd`, `extract`) to `.bashrc`/`.zshrc` |
| **a All** | Runs all of the above |

---

## Post-install steps

```bash
# Authenticate GitHub
gh auth login

# Generate SSH key and add to GitHub
ssh-keygen -t ed25519 -C "you@example.com"
gh ssh-key add ~/.ssh/id_ed25519.pub --title "$(hostname)"

# Verify Node.js
node --version && npm --version

# Verify Claude Code
claude --version
```

---

## Notes

- **Idempotent** — safe to re-run; already-installed tools are skipped.
- **ARM64 aware** — automatically selects the right binary/package for aarch64 (Raspberry Pi 4/5) and x86-64.
- Tested on Debian 13 (trixie) arm64. Should work on Debian 12 (bookworm) and Ubuntu 22.04/24.04.
- Docker installation requires a re-login for group membership (`docker` group) to take effect.
