#!/bin/bash

UPDATE="apt update -y"
INSTALL="apt install -y"

$UPDATE
$INSTALL zsh git curl
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc

# nuke oh-my-zsh's zshrc, replace it with mine
# assume target is root
( cd $HOME/; git clone https://github.com/wacky6/my_zshrc --depth 1; )
( rm -rf $HOME/.zshrc; ln -s $HOME/my_zshrc/zshrc $HOME/.zshrc; )

chsh -s $(which zsh) $USER
