#!/usr/bin/env bash

set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.vim"
VUNDLE_DIR="$TARGET_DIR/bundle/Vundle.vim"
TOOLS_VENV="$TARGET_DIR/z-vim-tools"
PYTHON_REQUIREMENT="${Z_VIM_PYTHON_REQUIREMENT:-3}"
INSTALL_DEPS=1
CHECK_ONLY=0

usage() {
    cat <<'EOF'
Usage: ./install.sh [options]

Options:
  --no-deps    Do not install or update git/vim/ruff.
  --check      Print dependency status and exit.
  -h, --help   Show this help.

By default the installer installs required git/vim dependencies when a
supported package manager is available, copies Vim config into HOME, installs
or updates Vim plugins with Vundle, then creates ~/.vim/z-vim-tools with a
Python found in PATH or uv and installs ruff there.
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

python_satisfies_requirement() {
    local python_bin="$1"

    "$python_bin" - "$PYTHON_REQUIREMENT" <<'PY' >/dev/null 2>&1
import re
import sys

requirement = sys.argv[1]
version = sys.version_info
match = re.fullmatch(r"(\d+)(?:\.(\d+))?", requirement)
if match is None:
    raise SystemExit(0 if version.major >= 3 else 1)

required_major = int(match.group(1))
required_minor = match.group(2)
if version.major != required_major:
    raise SystemExit(1)
if required_minor is not None and version.minor < int(required_minor):
    raise SystemExit(1)
PY
}

python_can_create_venv() {
    local python_bin="$1"
    local tmp_dir

    [ -x "$python_bin" ] || return 1
    tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/z-vim-venv.XXXXXX")" || return 1
    if "$python_bin" -m venv "$tmp_dir/venv" >/dev/null 2>&1; then
        rm -rf "$tmp_dir"
        return 0
    fi
    rm -rf "$tmp_dir"
    return 1
}

python_display_name() {
    local python_bin="$1"

    "$python_bin" - <<'PY' 2>/dev/null || printf '%s\n' "$python_bin"
import sys

print(f"{sys.executable} ({sys.version.split()[0]})")
PY
}

find_path_python() {
    local python_bin
    local python_cmd

    for python_cmd in python3 python; do
        if have "$python_cmd"; then
            python_bin="$(command -v "$python_cmd")"
            if python_satisfies_requirement "$python_bin" && python_can_create_venv "$python_bin"; then
                printf '%s\n' "$python_bin"
                return 0
            fi
        fi
    done
    return 1
}

find_uv_python() {
    local python_bin

    have uv || return 1
    python_bin="$(uv python find "$PYTHON_REQUIREMENT" 2>/dev/null || true)"
    [ -n "$python_bin" ] || return 1
    [ -x "$python_bin" ] || return 1
    if python_satisfies_requirement "$python_bin" && python_can_create_venv "$python_bin"; then
        printf '%s\n' "$python_bin"
        return 0
    fi
    return 1
}

find_python() {
    find_path_python || find_uv_python
}

tools_venv_has_pip() {
    [ -x "$TOOLS_VENV/bin/python" ] && "$TOOLS_VENV/bin/python" -m pip --version >/dev/null 2>&1
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
    local python_bin

    print_check "git" git || failed=1
    print_check "vim" vim || failed=1
    if python_bin="$(find_python)"; then
        printf 'ok      Python %s with venv (%s)\n' "$PYTHON_REQUIREMENT" "$(python_display_name "$python_bin")"
    else
        printf 'missing Python %s with working venv support (PATH python3/python or uv)\n' "$PYTHON_REQUIREMENT"
        failed=1
    fi
    print_check "ruff ($TOOLS_VENV/bin/ruff)" "$TOOLS_VENV/bin/ruff" || failed=1

    return "$failed"
}

install_system_dependencies() {
    local missing=0

    for cmd in git vim; do
        if ! have "$cmd"; then
            missing=1
        fi
    done

    if [ "$missing" -eq 0 ]; then
        return
    fi

    if [ "$INSTALL_DEPS" -eq 0 ]; then
        fail "git and vim are required; rerun without --no-deps or install them manually"
    fi

    case "$(uname -s)" in
        Darwin)
            have brew || fail "Homebrew is required to install missing macOS dependencies automatically"
            log "Installing missing system dependencies with Homebrew"
            brew install git vim
            ;;
        Linux)
            if have apt-get; then
                log "Installing missing system dependencies with apt-get"
                sudo apt-get update
                sudo apt-get install -y git vim
            elif have dnf; then
                log "Installing missing system dependencies with dnf"
                sudo dnf install -y git vim
            elif have pacman; then
                log "Installing missing system dependencies with pacman"
                sudo pacman -Sy --needed git vim
            else
                fail "unsupported Linux package manager; install git and vim manually"
            fi
            ;;
        *)
            fail "unsupported OS for automatic dependency installation: $(uname -s)"
            ;;
    esac

    for cmd in git vim; do
        have "$cmd" || fail "$cmd is still missing after dependency installation"
    done
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
    local python_bin

    if [ "$INSTALL_DEPS" -eq 0 ]; then
        return
    fi

    if [ -e "$TOOLS_VENV" ] && [ ! -x "$TOOLS_VENV/bin/python" ]; then
        fail "$TOOLS_VENV exists but is not a usable Python virtual environment"
    fi

    if [ -x "$TOOLS_VENV/bin/python" ] && ! tools_venv_has_pip; then
        log "Recreating Python tool environment because pip is missing"
        rm -rf "$TOOLS_VENV"
    fi

    if [ ! -x "$TOOLS_VENV/bin/python" ]; then
        if ! python_bin="$(find_python)"; then
            fail "Python $PYTHON_REQUIREMENT with working venv support was not found in PATH or uv; install Python for your user, for example with: uv python install $PYTHON_REQUIREMENT"
        fi

        log "Creating Python tool environment at $TOOLS_VENV with $(python_display_name "$python_bin")"
        if ! "$python_bin" -m venv "$TOOLS_VENV"; then
            fail "$python_bin -m venv failed"
        fi
    fi

    log "Installing Python tools: ruff"
    "$TOOLS_VENV/bin/python" -m pip install --upgrade pip
    "$TOOLS_VENV/bin/python" -m pip install --upgrade ruff
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
copy_config
install_vundle
install_plugins
install_python_tools
log "Installation complete"
