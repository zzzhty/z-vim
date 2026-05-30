# z-vim

Personal Vim configuration for terminal Vim, with Vundle-managed plugins,
Python lint/format support, VimTeX, snippets, CtrlP, Fugitive, Lightline, and
small editing defaults.

## Quick Install

```bash
./install.sh
```

The default installer is intended to be one-command for the normal setup. It:

- installs missing required command-line dependencies when a supported package
  manager is available;
- backs up existing `~/.vimrc`, `~/.gvimrc`, and `~/.vimrc.bundles` files with
  a timestamp suffix;
- keeps an existing `~/.vim` plugin directory instead of deleting it;
- creates `~/.vim/z-vim-tools`;
- installs or upgrades `flake8` and `black` inside that Python virtualenv;
- installs or updates Vundle;
- runs `:PluginInstall!` and `:PluginClean!`.

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
- `python3`
- Python `venv` support

If automatic installation is not available, install them manually first.

macOS:

```bash
brew install git vim python
```

Debian/Ubuntu:

```bash
sudo apt-get update
sudo apt-get install -y git vim python3 python3-venv python3-pip
```

Fedora:

```bash
sudo dnf install -y git vim python3 python3-pip
```

Arch:

```bash
sudo pacman -Sy --needed git vim python python-pip
```

## Python Tools

ALE is configured to use:

```text
~/.vim/z-vim-tools/bin/flake8
~/.vim/z-vim-tools/bin/black
```

`./install.sh` creates and updates that environment automatically. To do it
manually:

```bash
python3 -m venv ~/.vim/z-vim-tools
~/.vim/z-vim-tools/bin/python -m pip install --upgrade pip
~/.vim/z-vim-tools/bin/python -m pip install --upgrade flake8 black
```

## Optional LaTeX Dependencies

VimTeX is installed by default, but LaTeX compilation needs external tools.
Install these only if you edit TeX files:

- a TeX distribution with `xelatex`/`pdflatex`;
- `latexmk`;
- a PDF viewer.

macOS uses the system `open` command as the PDF viewer. A full no-GUI TeX
installation can be installed with:

```bash
brew install --cask mactex-no-gui
```

For a smaller macOS install, BasicTeX can work, but you may need to add missing
TeX packages with `tlmgr`:

```bash
brew install --cask basictex
```

Linux is configured for `okular`:

```bash
sudo apt-get install -y latexmk okular
```

Windows is configured for `SumatraPDF.exe`; install a TeX distribution and
ensure `latexmk` and `SumatraPDF.exe` are in `PATH`.

## Installed Plugins

- `dense-analysis/ale`: async linting and formatting
- `lervag/vimtex`: LaTeX editing
- `preservim/nerdcommenter`: commenting
- `godlygeek/tabular`: alignment
- `SirVer/ultisnips` and `honza/vim-snippets`: snippets
- `easymotion/vim-easymotion`: navigation
- `ctrlpvim/ctrlp.vim` and `tacahiroy/ctrlp-funky`: file/function search
- `tpope/vim-fugitive`: Git integration
- `luochen1990/rainbow`: rainbow parentheses
- `itchyny/lightline.vim`: statusline
- `preservim/vim-indent-guides`: indent guides

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
