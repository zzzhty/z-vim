#!/usr/bin/env bash

set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.vim"
VUNDLE_DIR="$TARGET_DIR/bundle/Vundle.vim"
TOOLS_VENV="$TARGET_DIR/tools"
INSTALL_DEPS=1
CHECK_ONLY=0
CLEAN_PLUGINS=0
USER_HOME="$HOME"
WORK_DIR=""
ACTIVATING=0
COMPLETED=0
LOCKED=0
TOOLS_PYTHON=""
BACKED_UP=()
ACTIVATED=()

usage() {
    cat <<'EOF'
Usage: ./install.sh [options]

Options:
  --no-deps    Do not install or update git/vim/ruff.
  --check      Print dependency status and exit.
  --clean-plugins  Remove undeclared plugins from the staged copy (opt-in).
  -h, --help   Show this help.

By default the installer installs required git/vim dependencies when a
supported package manager is available. Config, plugins and Python tools are
prepared in isolation before activation. Existing files and symlinks are
backed up in ~/.z-vim-install.*/backup. Undeclared plugins are kept by default.
Python tools use a stable private directory linked from ~/.vim/tools.
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
            if python_can_create_venv "$python_bin"; then
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
    python_bin="$(uv python find 3 2>/dev/null || true)"
    [ -n "$python_bin" ] || return 1
    [ -x "$python_bin" ] || return 1
    if python_can_create_venv "$python_bin"; then
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
        --clean-plugins)
            CLEAN_PLUGINS=1
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
        printf 'ok      Python with venv (%s)\n' "$(python_display_name "$python_bin")"
    else
        printf 'missing Python with working venv support (PATH python3/python or uv)\n'
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

# All writes before activation are isolated from the user's original config.
# Keep this directory after success: virtualenv scripts embed its absolute path.
prepare_stage() {
    # Resolve uv-managed Python while HOME still points to the user's caches.
    if [ "$INSTALL_DEPS" -eq 1 ]; then
        TOOLS_PYTHON="$(find_python)" || fail "Python with working venv support was not found in PATH or uv; install Python first (for example: uv python install 3)"
    fi
    if ! mkdir "$USER_HOME/.z-vim-install.lock" 2>/dev/null; then
        fail "another install may be running; check $USER_HOME/.z-vim-install.lock before retrying"
    fi
    LOCKED=1
    WORK_DIR="$(mktemp -d "$USER_HOME/.z-vim-install.XXXXXX")"
    mkdir -p "$WORK_DIR/home/.vim" "$WORK_DIR/backup"
    if [ -d "$USER_HOME/.vim" ]; then
        # Dereference links in the copy so plugin updates cannot follow them back
        # into the original tree. The original links themselves are backed up.
        cp -RL "$USER_HOME/.vim/." "$WORK_DIR/home/.vim/"
    fi
    export HOME="$WORK_DIR/home"
    export XDG_CACHE_HOME="$HOME/.cache" XDG_CONFIG_HOME="$HOME/.config"
    export XDG_DATA_HOME="$HOME/.local/share" XDG_STATE_HOME="$HOME/.local/state"
    mkdir -p "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME"
    TARGET_DIR="$HOME/.vim"
    VUNDLE_DIR="$TARGET_DIR/bundle/Vundle.vim"
    TOOLS_VENV="$WORK_DIR/tools"
    local git_file
    for git_file in "$TARGET_DIR"/bundle/*/.git; do
        [ ! -f "$git_file" ] || fail "plugin Git worktrees/submodules are not safe to update in a copy: $git_file"
        if [ -d "$git_file" ]; then
            [ ! -e "$git_file/commondir" ] || fail "plugin shared Git metadata is not safe to update in a copy: $git_file"
            if git config --file "$git_file/config" --includes --get core.worktree >/dev/null 2>&1; then
                fail "plugin core.worktree overrides are not safe to update in a copy: $git_file"
            fi
        fi
    done
}

finish() {
    local status=$? name rollback_failed=0
    trap - EXIT HUP INT TERM
    if [ "$COMPLETED" -eq 0 ] && [ -n "$WORK_DIR" ]; then
        if [ "$ACTIVATING" -eq 1 ]; then
            # Bash 3.2 (macOS) treats an empty array as unset with nounset.
            for name in ${ACTIVATED[@]+"${ACTIVATED[@]}"}; do
                # Move failed new state aside; never delete the only copy.
                mv "$USER_HOME/$name" "$WORK_DIR/failed-$name" || rollback_failed=1
            done
            for name in ${BACKED_UP[@]+"${BACKED_UP[@]}"}; do
                # Never nest an original inside a new directory that could not
                # be moved aside. Leave the backup at its documented path.
                if [ -e "$USER_HOME/$name" ] || [ -L "$USER_HOME/$name" ]; then
                    rollback_failed=1
                    continue
                fi
                mv "$WORK_DIR/backup/$name" "$USER_HOME/$name" || rollback_failed=1
            done
        fi
        if [ "$rollback_failed" -eq 1 ]; then
            printf 'Rollback incomplete; recover files from %s/backup\n' "$WORK_DIR" >&2
        else
            printf 'Installation failed; original config preserved/restored.\n' >&2
        fi
        printf 'Staged files and logs retained at %s\n' "$WORK_DIR" >&2
        [ "$status" -ne 0 ] || status=1
    fi
    if [ "$LOCKED" -eq 1 ]; then rmdir "$USER_HOME/.z-vim-install.lock" || true; fi
    exit "$status"
}

activate_config() {
    local name
    ACTIVATING=1
    for name in .vim .vimrc .vimrc.bundles; do
        if [ -e "$USER_HOME/$name" ] || [ -L "$USER_HOME/$name" ]; then
            mv "$USER_HOME/$name" "$WORK_DIR/backup/$name"
            BACKED_UP+=("$name")
        fi
        mv "$HOME/$name" "$USER_HOME/$name"
        ACTIVATED+=("$name")
    done
}

install_python_tools() {
    local python_bin

    if [ "$INSTALL_DEPS" -eq 0 ]; then
        return
    fi

    if [ -e "$TOOLS_VENV" ] && [ ! -d "$TOOLS_VENV" ]; then
        fail "$TOOLS_VENV exists but is not a directory"
    fi

    if [ -d "$TOOLS_VENV" ]; then
        local reason
        reason=""
        if [ ! -x "$TOOLS_VENV/bin/python" ]; then
            reason="its Python is unusable"
        elif ! tools_venv_has_pip; then
            reason="pip is missing"
        fi
        if [ -n "$reason" ]; then
            log "Recreating Python tool environment because $reason"
            rm -rf "$TOOLS_VENV"
        fi
    fi

    if [ ! -x "$TOOLS_VENV/bin/python" ]; then
        python_bin="$TOOLS_PYTHON"

        log "Creating Python tool environment at $TOOLS_VENV with $(python_display_name "$python_bin")"
        if ! "$python_bin" -m venv "$TOOLS_VENV"; then
            fail "$python_bin -m venv failed"
        fi
    fi

    log "Installing Python tools: ruff"
    "$TOOLS_VENV/bin/python" -m pip install --upgrade pip
    "$TOOLS_VENV/bin/python" -m pip install --upgrade ruff
    "$TOOLS_VENV/bin/ruff" --version
    # This is only a disposable staged copy, never the original tools directory.
    rm -rf "$TARGET_DIR/tools"
    ln -s "$TOOLS_VENV" "$TARGET_DIR/tools"
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
    log "Installing and verifying Vim plugins in staged HOME"
    cat > "$WORK_DIR/install-plugins.vim" <<'VIM'
" Configured filename filters must not hide plugin files during installation.
set wildignore=
try
    if empty(get(g:, 'vundle#bundles', []))
        throw 'No Vundle plugins were registered'
    endif
    for bundle in g:vundle#bundles
        let status = vundle#installer#install(1, bundle.name_spec)
        if index(['new', 'updated', 'todate', 'pinned'], status) < 0
            throw 'Plugin installation failed: ' . bundle.name_spec . ' (' . status . ')'
        endif
        if !isdirectory(bundle.path()) || empty(glob(bundle.path() . '/*', 1))
            throw 'Plugin files missing: ' . bundle.name_spec
        endif
    endfor
    if vundle#installer#docs() ==# 'error'
        throw 'Plugin documentation generation failed'
    endif
    if $Z_VIM_CLEAN_PLUGINS ==# '1'
        call vundle#installer#clean(1)
        let declared = map(copy(g:vundle#bundles), 'fnamemodify(v:val.path(), ":p")')
        for candidate in globpath(g:vundle#bundle_dir, '*', 1, 1)
            if index(declared, fnamemodify(candidate, ':p')) < 0
                throw 'Plugin cleanup failed: ' . candidate
            endif
        endfor
    endif
    call writefile(['verified'], $Z_VIM_PLUGIN_MARKER)
catch
    echom v:exception
    call writefile(get(g:, 'vundle#log', []) + [v:exception], $Z_VIM_PLUGIN_LOG)
    cquit
endtry
call writefile(get(g:, 'vundle#log', []), $Z_VIM_PLUGIN_LOG)
qall!
VIM
    # Vundle can report failed clones while Vim itself exits successfully. Check
    # each installer result and require a marker written only after verification.
    Z_VIM_PLUGIN_LOG="$WORK_DIR/vundle.log" Z_VIM_CLEAN_PLUGINS="$CLEAN_PLUGINS" Z_VIM_PLUGIN_MARKER="$WORK_DIR/plugins-ok" \
        SHELL=/bin/sh vim -n -i NONE -es -u "$HOME/.vimrc" \
        -V1"$WORK_DIR/plugins.log" -S "$WORK_DIR/install-plugins.vim"
    [ -f "$WORK_DIR/plugins-ok" ] || fail "plugin verification did not finish; see $WORK_DIR/plugins.log"
    SHELL=/bin/sh vim -n -i NONE -es -u "$HOME/.vimrc" \
        -V1"$WORK_DIR/startup.log" -c 'qall!'
}

if [ "$CHECK_ONLY" -eq 1 ]; then
    check_dependencies
    exit "$?"
fi

trap finish EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
install_system_dependencies
prepare_stage
copy_config
install_python_tools
install_vundle
install_plugins
activate_config
COMPLETED=1
log "Installation complete. Backups and logs: $WORK_DIR"
log "Keep this directory: ~/.vim/tools may link to its Python environment."
