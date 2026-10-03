# z-vim

Personal Vim configuration for terminal Vim, with Vundle-managed plugins,
Python lint/format support, snippets, CtrlP, Fugitive, Lightline, and small
editing defaults.

## Quick Install

```bash
./install.sh
```

The default installer is intended to be one-command for the normal setup. It:

- installs missing required `git`/`vim` dependencies when a supported package
  manager is available;
- stages config, a copy of existing plugins, and Python tools in an isolated HOME;
- verifies each Vundle install/update result and a headless Vim startup before
  activating the new config;
- preserves undeclared plugins unless `--clean-plugins` is explicitly supplied;
- moves original `~/.vim`, `~/.vimrc`, and `~/.vimrc.bundles` (including dangling
  symlinks) into a unique `~/.z-vim-install.*/backup` directory;
- leaves `~/.gvimrc` untouched;
- restores those originals if activation fails;
- links `~/.vim/tools` to the new Python virtualenv in that stable install directory
  and installs/upgrades `ruff` there.

The staged copy dereferences existing plugin/config-directory links so updates
cannot alter their external targets. Originals keep their exact link text in the
backup. Git worktree/submodule plugins (`.git` files) are rejected rather than
updating their external Git metadata. A full copy requires enough free disk space
for your existing `.vim` directory. Concurrent installs are rejected.

Useful modes:

```bash
./install.sh --check     # print dependency status
./install.sh --no-deps   # only copy Vim config and update Vim plugins
./install.sh --clean-plugins # opt in to removing undeclared plugins
./install.sh --help
```

## Required Dependencies

The default installer can install these automatically on macOS with Homebrew,
Debian/Ubuntu with `apt-get`, Fedora with `dnf`, and Arch with `pacman`:

- `git`
- `vim`

If automatic installation is not available, install them manually first.

macOS:

```bash
brew install git vim
```

Debian/Ubuntu:

```bash
sudo apt-get update
sudo apt-get install -y git vim
```

Fedora:

```bash
sudo dnf install -y git vim
```

Arch:

```bash
sudo pacman -Sy --needed git vim
```

## Python Tools

ALE is configured to use:

```text
~/.vim/tools/bin/ruff
```

`./install.sh` creates and updates that environment automatically when it can
find a Python that can create virtual environments. It searches in this order:

- `python3` then `python` from `PATH`;
- `uv python find 3`, if `uv` is installed.

If neither source works, install Python in user space and rerun the installer.
For example:

```bash
uv python install 3
./install.sh
```

To create the tools environment manually:

```bash
python3 -m venv ~/.vim/tools
~/.vim/tools/bin/python -m pip install --upgrade pip
~/.vim/tools/bin/python -m pip install --upgrade ruff
```

## Installed Plugins

Plugins are declared and configured in `vimrc.bundles`; see that file (or run
`:PluginList` inside Vim) for the current set. At a glance it provides async
linting and formatting, commenting, alignment, snippets, fast cursor movement,
file and function search, Git integration, and statusline/indent display.

## Maintenance

After changing `vimrc.bundles`, run:

```bash
./install.sh
```

or inside Vim (manual plugin updates are not covered by installer rollback):

```vim
:PluginInstall!
:PluginClean  " review removal interactively, only if desired
```

### Recovery and verification

Every install prints its unique `~/.z-vim-install.*` directory. Keep successful
install directories: the active Python tools may link into one of them. Failures
retain staged files, `plugins.log`, `vundle.log`, and `startup.log` when available.
The original HOME config is untouched until all staging checks succeed. System
package-manager changes are not rolled back. Interruptions during activation are
rolled back where possible; SIGKILL, power loss, or filesystem errors may require
manual recovery. If the lock remains after such an interruption, first confirm no
installer is running before removing the empty `~/.z-vim-install.lock` directory.

To restore, close Vim, move the newly installed `.vim`, `.vimrc`, and
`.vimrc.bundles` aside, and move each original from the chosen install's `backup`
directory back to its exact HOME path. Missing backup entries mean the path did
not exist before that installation. Restore symlinks themselves, not their targets;
relative links resolve correctly again at their original locations. Do not remove
an install directory while `~/.vim/tools` still points into it. Backups may contain
private config and history; install directories are created with private permissions.

Run deterministic, offline installer regression tests with:

```bash
bash tests/install-test.sh
```

These use temporary HOME directories and stub Git/Vim to exercise transaction
boundaries. They do not prove network availability or compatibility of upstream
plugins; an actual install also performs its own Vundle and startup checks.
