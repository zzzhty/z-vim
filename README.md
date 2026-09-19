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
- backs up existing `~/.vimrc`, `~/.gvimrc`, and `~/.vimrc.bundles` files with
  a timestamp suffix;
- keeps an existing `~/.vim` plugin directory instead of deleting it;
- copies `vimrc` and `vimrc.bundles` to `~/.vimrc` and `~/.vimrc.bundles`;
- installs or updates Vundle;
- runs `:PluginInstall!` and `:PluginClean!`;
- creates `~/.vim/tools` with a Python found in `PATH` or `uv`;
- installs or upgrades `ruff` inside that Python virtualenv.

Useful modes:

```bash
./install.sh --check     # print dependency status
./install.sh --no-deps   # only copy Vim config and update Vim plugins
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

or inside Vim:

```vim
:PluginInstall!
:PluginClean!
```
