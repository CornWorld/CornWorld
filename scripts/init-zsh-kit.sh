#!/usr/bin/bash

# Author: CornWorld(https://github.com/CornWorld)

# Description: Install zsh + oh-my-zsh + powerlevel10k on a initial archlinux where bash is already installed.

GITHUB_REPO_PREFIX=https://github.com
GITHUB_REPO_PREFIX_CN=https://hub.fgit.cf
GITHUB_RAW_PREFIX=https://raw.githubusercontent.com
GITHUB_RAW_PREFIX_CN=https://raw.fgit.cf

if [[ "$(id -u)" -ne 0 ]]; then
    echo "Error: This script must be run as root."
    exit 1
fi

echo "Please select your location:"
echo "1. Chinese Mainland"
echo "2. Other"
read -p "Enter your choice (1 or 2): " place
case $place in
    1)
        GITHUB_REPO_PREFIX=$GITHUB_REPO_PREFIX_CN
        GITHUB_RAW_PREFIX=$GITHUB_RAW_PREFIX_CN
        ;;
    2)
        ;;
    *)
        # Handle invalid input
        echo "Error: Invalid option. Please enter either '1' or '2'."
        # exit 1
        ;;
esac

# Install zsh
pacman -Sy --noconfirm git wget zsh

# Change default shell to zsh
chsh -s /bin/zsh

# Install ohmyzsh
wget -O $HOME/install-ohmyzsh.sh $GITHUB_RAW_PREFIX/ohmyzsh/ohmyzsh/master/tools/install.sh
sed -i "s|https://github.com|$GITHUB_REPO_PREFIX|" $HOME/install-ohmyzsh.sh
sed -i 's|exec zsh -l||' 
mv $HOME/.oh-my-zsh $HOME/.oh-my-zsh-old
sh $HOME/install-ohmyzsh.sh
rm $HOME/install-ohmyzsh.sh

# Install Powerlevel10k
git clone --depth=1 $GITHUB_REPO_PREFIX/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

# Confirm whether ~/.zshrc existed
if [[ -f "$HOME/.zshrc" ]]; then
    # Use grep and sed to set theme
    grep -q 'ZSH_THEME="powerlevel10k/powerlevel10k"' $HOME/.zshrc || sed -i 's|ZSH_THEME=".*"|ZSH_THEME="powerlevel10k/powerlevel10k"|' $HOME/.zshrc
else
    # If not existed, create and write
    echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' > $HOME/.zshrc 
fi

echo '[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh' >> $HOME/.zshrc

# Download .p10k.zsh and .dircolors to $HOME
wget -O $HOME/.p10k.zsh $GITHUB_RAW_PREFIX/CornWorld/CornWorld/master/.p10k.zsh
wget -O $HOME/.dircolors $GITHUB_RAW_PREFIX/CornWorld/CornWorld/master/.dircolors

pt="
alias rm='rm -I --preserve-root'
alias chmod='chmod --preserve-root'
alias chown='chown --preserve-root'
alias chgrp='chgrp --preserve-root'
"

echo $pt >> $HOME/.zshrc
echo $pt >> $HOME/.bashrc

echo "======Enjoy!======"

zsh