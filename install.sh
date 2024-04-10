#!/bin/bash

BASEDIR=$(dirname $0)
cd $BASEDIR
CURRENT_DIR=`pwd`
TARGET_DIR=$HOME/.vim

echo "Step1: backing up current vim config"
today=`date +%Y%m%d`
for i in $HOME/.vim $HOME/.vimrc $HOME/.gvimrc $HOME/.vimrc.bundles; do [ -e $i ] && [ ! -L $i ] && mv $i $i.$today; done
for i in $HOME/.vim $HOME/.vimrc $HOME/.gvimrc $HOME/.vimrc.bundles; do [ -L $i ] && unlink $i ; done

echo "Step2: copy configure profiles"
cp $CURRENT_DIR/vimrc $HOME/.vimrc
cp $CURRENT_DIR/vimrc.bundles $HOME/.vimrc.bundles

echo "Step3: install vundle"
if [ ! -e $TARGET_DIR/bundle/Vundle.vim ]; then
    echo "Installing Vundle"
    git clone https://github.com/vundleVim/Vundle.vim.git $TARGET_DIR/bundle/Vundle.vim
else
    echo "Upgrade Vundle"
    cd "$TARGET_DIR/bundle/Vundle.vim" && git pull origin main
fi

echo "Step4: update/install plugins using Vundle"
system_shell=$SHELL
export SHELL="/bin/sh"
vim -u $HOME/.vimrc +PluginInstall! +PluginClean +qall
export SHELL=$system_shell

echo "Completely installed!"
# Done
