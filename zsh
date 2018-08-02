#!/bin/bash

UPDATE="apt update -y"
INSTALL="apt install -y"

$UPDATE
$INSTALL zsh git curl sed
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh | sed '/env zsh/c\\')"

# nuke oh-my-zsh's zshrc, replace it with mine
# assume target is root
( cd /root/; git clone https://github.com/wacky6/my_zshrc --depth 1; )
( rm -rf /root/.zshrc; ln -s /root/my_zshrc/zshrc /root/.zshrc; )

