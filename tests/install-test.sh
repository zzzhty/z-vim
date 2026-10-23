#!/usr/bin/env bash
# Deterministic installer integration tests. No network or user's HOME writes.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
TEST_BASH="${TEST_BASH:-$BASH}"
REAL_MV="$(command -v mv)"
REAL_GIT="$(command -v git)"
export REAL_MV REAL_GIT
cat > "$TMP/bin/git" <<'SH'
#!/usr/bin/env bash
set -eu
if [ "$1" = config ]; then exec "$REAL_GIT" "$@"; fi
if [ "${FAIL_DOWNLOAD:-0}" = 1 ]; then exit 7; fi
if [ "$1" = clone ]; then
    mkdir -p "$3/autoload"
    echo fixture > "$3/autoload/vundle.vim"
fi
SH
cat > "$TMP/bin/vim" <<'SH'
#!/usr/bin/env bash
set -eu
# Even a zero exit without verified plugins must be treated as failure.
if [ "${FAIL_PLUGIN:-0}" = 1 ]; then exit 0; fi
if [ "${FAIL_STARTUP:-0}" = 1 ] && [ -z "${Z_VIM_PLUGIN_MARKER:-}" ]; then exit 1; fi
if [ -n "${Z_VIM_PLUGIN_MARKER:-}" ]; then
    if [ "${Z_VIM_CLEAN_PLUGINS:-0}" = 1 ]; then rm -rf "$HOME/.vim/bundle/extra"; fi
    printf 'verified\n' > "$Z_VIM_PLUGIN_MARKER"
fi
SH
cat > "$TMP/bin/mv" <<'SH'
#!/usr/bin/env bash
set -eu
if [ "${FAIL_FIRST_ACTIVATION:-0}" = 1 ] && [[ "$1" = */home/.vim ]]; then exit 9; fi
if [ "${FAIL_ROLLBACK:-0}" = 1 ] && [[ "$2" = */failed-.vim ]]; then exit 9; fi
if [ "${FAIL_ACTIVATION:-0}" = 1 ] && [[ "$1" = */home/.vimrc ]]; then exit 9; fi
exec "$REAL_MV" "$@"
SH
chmod +x "$TMP/bin/"*
export PATH="$TMP/bin:$PATH"
new_home() { HOME="$TMP/$1"; export HOME; mkdir -p "$HOME"; }
run() { "$TEST_BASH" "$ROOT/install.sh" --no-deps "$@" > "$TMP/output" 2>&1; }
expect_failure() { if run "$@"; then cat "$TMP/output"; echo 'Expected failure' >&2; exit 1; fi; }
assert_original() {
    [ -L "$HOME/.vim" ] && [ "$(readlink "$HOME/.vim")" = "$TMP/original" ]
    [ -L "$HOME/.vimrc" ] && [ "$(readlink "$HOME/.vimrc")" = 'missing-relative-target' ]
    [ "$(cat "$TMP/original/bundle/extra/keep")" = precious ]
}
new_home 'first home'
run
cmp "$ROOT/vimrc" "$HOME/.vimrc"
[ -d "$HOME/.vim/bundle/Vundle.vim" ]
mkdir -p "$HOME/.vim/bundle/extra"
echo precious > "$HOME/.vim/bundle/extra/keep"
run
[ "$(cat "$HOME/.vim/bundle/extra/keep")" = precious ]
[ "$(find "$HOME" -path '*/backup/.vimrc' | wc -l)" -eq 1 ]
echo 'PASS first/repeat install; undeclared plugins retained'
run --clean-plugins
[ ! -e "$HOME/.vim/bundle/extra" ]
find "$HOME" -path '*/backup/.vim/bundle/extra/keep' | grep -q .
echo 'PASS explicit cleanup retains recoverable backup'
mkdir -p "$TMP/original/bundle/extra"
echo precious > "$TMP/original/bundle/extra/keep"
for failure in FAIL_DOWNLOAD FAIL_PLUGIN FAIL_STARTUP FAIL_ACTIVATION FAIL_FIRST_ACTIVATION; do
    new_home "$failure"
    ln -s "$TMP/original" "$HOME/.vim"
    ln -s missing-relative-target "$HOME/.vimrc"
    export "$failure=1"
    expect_failure
    unset "$failure"
    assert_original
    [ ! -e "$HOME/.z-vim-install.lock" ]
    echo "PASS $failure leaves original links and plugin data intact"
done
# No original paths means both rollback arrays can be empty on macOS Bash.
new_home first-activation-failure
FAIL_FIRST_ACTIVATION=1 expect_failure
[ ! -e "$HOME/.vim" ]
[ ! -e "$HOME/.z-vim-install.lock" ]
echo 'PASS first activation failure on empty HOME releases lock'
new_home rollback-failure
mkdir -p "$HOME/.vim"
echo precious > "$HOME/.vim/original"
FAIL_ACTIVATION=1 FAIL_ROLLBACK=1 expect_failure
backup="$(find "$HOME" -type d -name backup)"
[ "$(cat "$backup/.vim/original")" = precious ]
[ ! -e "$HOME/.vim/.vim" ]
grep -q 'Rollback incomplete' "$TMP/output"
[ ! -e "$HOME/.z-vim-install.lock" ]
echo 'PASS failed rollback keeps original at the documented backup path'
new_home links
ln -s "$TMP/original" "$HOME/.vim"
ln -s missing-relative-target "$HOME/.vimrc"
ln -s original-gvimrc "$HOME/.gvimrc"
run
[ ! -L "$HOME/.vim" ]
[ -L "$HOME/.gvimrc" ]
backup="$(find "$HOME" -type d -name backup)"
[ -L "$backup/.vim" ] && [ -L "$backup/.vimrc" ]
[ "$(readlink "$backup/.vimrc")" = missing-relative-target ]
[ "$(cat "$TMP/original/bundle/extra/keep")" = precious ]
echo 'PASS existing/dangling symlinks backed up; gvimrc and external targets untouched'
new_home nested
mkdir -p "$HOME/.vim/bundle"
ln -s "$TMP/original/bundle/extra" "$HOME/.vim/bundle/extra"
run --clean-plugins
[ "$(cat "$TMP/original/bundle/extra/keep")" = precious ]
backup="$(find "$HOME" -type d -name backup)"
[ -L "$backup/.vim/bundle/extra" ]
echo 'PASS cleaning staged nested symlink never changes external target'
new_home worktree
mkdir -p "$HOME/.vim/bundle/worktree"
echo 'gitdir: /external/metadata' > "$HOME/.vim/bundle/worktree/.git"
expect_failure
[ -f "$HOME/.vim/bundle/worktree/.git" ]
echo 'PASS external worktree metadata rejected before plugin updates'
new_home shared-git
mkdir -p "$HOME/.vim/bundle/extra/.git"
echo /external/metadata > "$HOME/.vim/bundle/extra/.git/commondir"
expect_failure
grep -q 'shared Git metadata' "$TMP/output"
echo 'PASS shared Git metadata rejected before updates'
new_home redirected-git
mkdir -p "$HOME/.vim/bundle/extra/.git"
"$REAL_GIT" config --file "$HOME/.vim/bundle/extra/.git/config" core.worktree "$TMP/original"
expect_failure
grep -q 'core.worktree overrides' "$TMP/output"
[ "$(cat "$TMP/original/bundle/extra/keep")" = precious ]
echo 'PASS Git worktree override rejected before external files can change'
new_home locked
mkdir "$HOME/.z-vim-install.lock"
expect_failure
[ ! -e "$HOME/.vim" ]
echo 'PASS concurrent/stale lock fails safely'

# Exercise Python tool staging without pip or package-manager network access.
cat > "$TMP/bin/python3" <<'SH'
#!/usr/bin/env bash
set -eu
if [ "${1:-}" = -m ] && [ "${2:-}" = venv ]; then
    mkdir -p "$3/bin"
    cat > "$3/bin/python" <<'PY'
#!/usr/bin/env bash
set -eu
if [ "${FAIL_PIP:-0}" = 1 ]; then exit 8; fi
PY
    printf '#!/bin/sh\necho ruff-fixture\n' > "$3/bin/ruff"
    chmod +x "$3/bin/python" "$3/bin/ruff"
else
    echo python-fixture
fi
SH
chmod +x "$TMP/bin/python3"
new_home python-failure
echo original > "$HOME/.vimrc"
if FAIL_PIP=1 "$TEST_BASH" "$ROOT/install.sh" > "$TMP/output" 2>&1; then exit 1; fi
[ "$(cat "$HOME/.vimrc")" = original ]
[ ! -e "$HOME/.vim" ]
echo 'PASS Python tool failure leaves original config untouched'
new_home python-success
"$TEST_BASH" "$ROOT/install.sh" > "$TMP/output" 2>&1
[ -L "$HOME/.vim/tools" ]
[ "$("$HOME/.vim/tools/bin/ruff" --version)" = ruff-fixture ]
"$HOME/.vim/tools/bin/python" -m pip --version
"$TEST_BASH" "$ROOT/install.sh" > "$TMP/output" 2>&1
[ "$("$HOME/.vim/tools/bin/ruff" --version)" = ruff-fixture ]
echo 'PASS repeated Python install retains a working stable tools link'
