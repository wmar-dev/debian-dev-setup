# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Two idempotent bash scripts for setting up a Debian/Ubuntu development environment from scratch, mirroring the [wmar-dev/macbook](https://github.com/wmar-dev/macbook) repo for Linux. Targets Debian 13 (trixie) on ARM64 (Raspberry Pi) but works on x86-64 and older Debian/Ubuntu releases.

## Scripts

**`setup.sh`** — run first on a fresh machine. Installs via `apt` + direct installers: build-essential, git, ffmpeg, graphviz, sqlite3, GitHub CLI (official apt repo), nvm + Node.js 22, Claude Code CLI, uv, and Deno. Prompts for git globals, creates `~/Developer/` subdirs, and appends PATH/nvm blocks to `.bashrc`/`.zshrc`.

**`dev-environment-setup.sh`** — interactive menu run after `setup.sh`. Each menu item is a self-contained `setup_*` function:
- `setup_nodejs` — npm global packages (TypeScript, ESLint, Prettier, etc.)
- `setup_python` — Python 3.13 via uv + template venv in `~/Developer/python-template/`
- `setup_ruby` — rbenv + Ruby 3.3 + Bundler
- `setup_git` — git aliases and global `.gitignore`
- `setup_docker` — Docker CE from official repo + compose template
- `setup_vscode` — VS Code `.deb` download (arm64/x64 auto-detected) + extensions
- `setup_shell` — aliases and helper functions appended to shell RC

## Key conventions

- Both scripts use `set -e` and share the same color/logging helpers (`info`, `success`, `warn`, `error`).
- Idempotency: every install is guarded with `command -v` or `[[ -d ... ]]` checks before acting.
- ARM64 awareness: use `$(dpkg --print-architecture)` when constructing download URLs or apt sources, not hardcoded arch strings.
- Shell RC target: detect zsh vs bash via `$SHELL`, default to `.bashrc`.
- Adding to shell RC: use a string marker (`grep -qF "$MARKER"`) to avoid duplicate blocks on re-runs.

## Testing changes

Syntax-check both scripts before committing:

```bash
bash -n setup.sh
bash -n dev-environment-setup.sh
```

There is no automated test suite — validate changes by running against a fresh Debian container or VM:

```bash
docker run --rm -it debian:trixie bash
# inside container:
apt-get update && apt-get install -y git curl sudo
git clone <repo> && cd linux-dev-setup
./setup.sh
```
