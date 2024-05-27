#!/bin/bash

UPDATE="apt update -y"
INSTALL="apt install -y"

$UPDATE
$INSTALL zsh git curl

# set important environment variables if they haven't been set
# POSIX: https://pubs.opengroup.org/onlinepubs/009695299/utilities/id.html
USER=${USER:-$(id -u -n)}
# POSIX: https://pubs.opengroup.org/onlinepubs/009696899/basedefs/xbd_chap08.html#tag_08_03
HOME="${HOME:-$(getent passwd $USER 2>/dev/null | cut -d: -f6)}"
# macOS does not have getent, but this works even if $HOME is unset
HOME="${HOME:-$(eval echo ~$USER)}"

# oh-my-zsh install
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc

# nuke oh-my-zsh's zshrc, replace it with mine
# assume target is root
MY_ZSHRC="https://github.com/wacky6/my_zshrc"
( cd $HOME/; git clone $MY_ZSHRC --depth 1; )
( rm -rf $HOME/.zshrc; ln -s $HOME/my_zshrc/zshrc $HOME/.zshrc; )

chsh -s $(which zsh) $USER

# Install auto-sync crontab job, assume zsh is installed by zsh script in this directory.
# Trigger at 05:$RAND_MIN local time (early morning).
# A night owl (me) is unlikely to fiddling with zshrc at this time.
_install_crontab () {
  if ! which uname > /dev/null ; then
    echo "Won't install crontab: can't find uname. Is this a POSIX system?"
    return
  fi

  OS_IDENT=$(uname -s)
  if [ "$OS_IDENT" == "Darwin" ] ; then
    echo "Won't install crontab: running on MacOS."
    return
  fi

  # Use CMD_PREFIX to detect existing crontab installation.
  CMD_PREFIX="wacky6-zsh-sync"

  if [ $( crontab -l | grep -o $CMD_PREFIX | wc -l ) -gt 0 ] ; then
    echo "Skip install crontab: already installed."
    crontab -l | grep $CMD_PREFIX
    return
  fi

  RAND_MIN=$(( $RANDOM % 60 ))
  HOME_DIR=$HOME
  crontab -l | {
    cat ;
    echo "$RAND_MIN 5 * * * ( echo $CMD_PREFIX ; cd "${HOME_DIR}/my_zshrc" ; git fetch origin && git merge --ff-only origin/master ; "${HOME_DIR}/.oh-my-zsh/tools/upgrade.sh" ) "
  } | crontab -

  if [ "$?" == "0" ] ; then
    echo "Installed zsh-sync crontab."
    crontab -l | grep $CMD_PREFIX
  else
    echo "Failed to install zsh-sync crontab."
  fi
}

_install_crontab
