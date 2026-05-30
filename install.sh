#!/usr/bin/env bash

set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.vim"
VUNDLE_DIR="$TARGET_DIR/bundle/Vundle.vim"
TOOLS_VENV="$TARGET_DIR/z-vim-tools"
INSTALL_DEPS=1
CHECK_ONLY=0

usage() {
    cat <<'EOF'
Usage: ./install.sh [options]

Options:
  --no-deps    Do not install or update git/vim/python/flake8/black.
  --check      Print dependency status and exit.
  -h, --help   Show this help.

By default the installer installs required command-line dependencies when a
supported package manager is available, creates ~/.vim/z-vim-tools, installs
flake8 and black there, then installs or updates Vim plugins with Vundle.
EOF
}

log() {
    printf '==> %s\n' "$*"
}

fail() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

have() {
    command -v "$1" >/dev/null 2>&1
}

python_has_venv() {
    have python3 && python3 -c 'import venv' >/dev/null 2>&1
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --no-deps)
            INSTALL_DEPS=0
            ;;
        --check)
            CHECK_ONLY=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "unknown option: $1"
            ;;
    esac
    shift
done

print_check() {
    local label="$1"
    local path="$2"

    if [ -x "$path" ] || have "$path"; then
        printf 'ok      %s\n' "$label"
    else
        printf 'missing %s\n' "$label"
        return 1
    fi
}

check_dependencies() {
    local failed=0

    print_check "git" git || failed=1
    print_check "vim" vim || failed=1
    print_check "python3" python3 || failed=1
    if python_has_venv; then
        printf 'ok      python3 venv module\n'
    else
        printf 'missing python3 venv module\n'
        failed=1
    fi
    print_check "flake8 ($TOOLS_VENV/bin/flake8)" "$TOOLS_VENV/bin/flake8" || failed=1
    print_check "black ($TOOLS_VENV/bin/black)" "$TOOLS_VENV/bin/black" || failed=1

    if have latexmk; then
        printf 'ok      latexmk (optional VimTeX compiler)\n'
    else
        printf 'missing latexmk (optional VimTeX compiler)\n'
    fi

    return "$failed"
}

install_system_dependencies() {
    local missing=0

    for cmd in git vim python3; do
        if ! have "$cmd"; then
            missing=1
        fi
    done
    if ! python_has_venv; then
        missing=1
    fi

    if [ "$missing" -eq 0 ]; then
        return
    fi

    if [ "$INSTALL_DEPS" -eq 0 ]; then
        fail "git, vim, and python3 are required; rerun without --no-deps or install them manually"
    fi

    case "$(uname -s)" in
        Darwin)
            have brew || fail "Homebrew is required to install missing macOS dependencies automatically"
            log "Installing missing system dependencies with Homebrew"
            brew install git vim python
            ;;
        Linux)
            if have apt-get; then
                log "Installing missing system dependencies with apt-get"
                sudo apt-get update
                sudo apt-get install -y git vim python3 python3-venv python3-pip
            elif have dnf; then
                log "Installing missing system dependencies with dnf"
                sudo dnf install -y git vim python3 python3-pip
            elif have pacman; then
                log "Installing missing system dependencies with pacman"
                sudo pacman -Sy --needed git vim python python-pip
            else
                fail "unsupported Linux package manager; install git, vim, python3, venv, and pip manually"
            fi
            ;;
        *)
            fail "unsupported OS for automatic dependency installation: $(uname -s)"
            ;;
    esac

    for cmd in git vim python3; do
        have "$cmd" || fail "$cmd is still missing after dependency installation"
    done
    python_has_venv || fail "python3 venv module is still missing after dependency installation"
}

prepare_vim_home() {
    local today

    log "Backing up current vim config"
    today="$(date +%Y%m%d%H%M%S)"
    for i in "$HOME/.vimrc" "$HOME/.gvimrc" "$HOME/.vimrc.bundles"; do
        if [ -e "$i" ] && [ ! -L "$i" ]; then
            mv "$i" "$i.$today"
        fi
    done
    for i in "$HOME/.vimrc" "$HOME/.gvimrc" "$HOME/.vimrc.bundles"; do
        if [ -L "$i" ]; then
            unlink "$i"
        fi
    done
    if [ -L "$TARGET_DIR" ]; then
        unlink "$TARGET_DIR"
    elif [ -e "$TARGET_DIR" ] && [ ! -d "$TARGET_DIR" ]; then
        mv "$TARGET_DIR" "$TARGET_DIR.$today"
    fi
    mkdir -p "$TARGET_DIR"
}

install_python_tools() {
    if [ "$INSTALL_DEPS" -eq 0 ]; then
        return
    fi

    if [ -e "$TOOLS_VENV" ] && [ ! -x "$TOOLS_VENV/bin/python" ]; then
        fail "$TOOLS_VENV exists but is not a usable Python virtual environment"
    fi

    if [ ! -x "$TOOLS_VENV/bin/python" ]; then
        log "Creating Python tool environment at $TOOLS_VENV"
        if ! python3 -m venv "$TOOLS_VENV"; then
            fail "python3 -m venv failed; install the Python venv package and rerun"
        fi
    fi

    log "Installing Python tools: flake8 black"
    "$TOOLS_VENV/bin/python" -m pip install --upgrade pip
    "$TOOLS_VENV/bin/python" -m pip install --upgrade flake8 black
}

copy_config() {
    log "Copying vim config"
    cp "$CURRENT_DIR/vimrc" "$HOME/.vimrc"
    cp "$CURRENT_DIR/vimrc.bundles" "$HOME/.vimrc.bundles"
}

install_vundle() {
    log "Installing or updating Vundle"
    mkdir -p "$TARGET_DIR/bundle"
    if [ ! -e "$VUNDLE_DIR" ]; then
        git clone https://github.com/VundleVim/Vundle.vim.git "$VUNDLE_DIR"
    else
        git -C "$VUNDLE_DIR" pull --ff-only origin master
    fi
}

install_plugins() {
    local system_shell

    log "Installing and cleaning Vim plugins"
    system_shell="${SHELL:-/bin/sh}"
    export SHELL="/bin/sh"
    vim -u "$HOME/.vimrc" +PluginInstall! +PluginClean! +qall
    export SHELL="$system_shell"
}

if [ "$CHECK_ONLY" -eq 1 ]; then
    check_dependencies
    exit "$?"
fi

install_system_dependencies
prepare_vim_home
install_python_tools
copy_config
install_vundle
install_plugins
log "Installation complete"
