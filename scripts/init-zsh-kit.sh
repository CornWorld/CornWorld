#!/usr/bin/bash

# Author: CornWorld(https://github.com/CornWorld)

# Description: Install zsh + oh-my-zsh + powerlevel10k on a initial archlinux where bash is already installed.

GITHUB_REPO_PREFIX=https://github.com
GITHUB_REPO_PREFIX_CN=https://hub.fgit.cf
GITHUB_RAW_PREFIX=https://raw.githubusercontent.com
GITHUB_RAW_PREFIX_CN=https://raw.fgit.cf

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
sudo pacman -Sy --noconfirm git wget zsh

# Change default shell to zsh
chsh -s /bin/zsh

# Install ohmyzsh
wget -O $HOME/install-ohmyzsh.sh $GITHUB_RAW_PREFIX/ohmyzsh/ohmyzsh/master/tools/install.sh
sed -i "s|https://github.com|$GITHUB_REPO_PREFIX|" $HOME/install-ohmyzsh.sh
sed -i 's|exec zsh -l||' $HOME/install-ohmyzsh.sh
mv $HOME/.oh-my-zsh $HOME/.oh-my-zsh-backup_$RANDOM
sh $HOME/install-ohmyzsh.sh
rm $HOME/install-ohmyzsh.sh

# Install Powerlevel10k
git clone --depth=1 $GITHUB_REPO_PREFIX/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

# Confirm whether $HOME/.zshrc existed
if [[ -f "$HOME/.zshrc" ]]; then
    # Use grep and sed to set theme
    grep -q 'ZSH_THEME="powerlevel10k/powerlevel10k"' $HOME/.zshrc || sed -i 's|ZSH_THEME=".*"|ZSH_THEME="powerlevel10k/powerlevel10k"|' $HOME/.zshrc
else
    # If not existed, create and write
    echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' > $HOME/.zshrc 
fi

# Download .p10k.zsh and .dircolors to $HOME
wget -O $HOME/.p10k.zsh $GITHUB_RAW_PREFIX/CornWorld/CornWorld/master/.p10k.zsh
wget -O $HOME/.dircolors $GITHUB_RAW_PREFIX/CornWorld/CornWorld/master/.dircolors

original_zshrc=$(cat $HOME/.zshrc)
echo $original_zshrc > $HOME/.zshrc_backup_$RANDOM
pt="
alias rm='rm -I --preserve-root'
alias chmod='chmod --preserve-root'
alias chown='chown --preserve-root'
alias chgrp='chgrp --preserve-root'
"
p10k_apply_config='
[[ ! -f $HOME/.p10k.zsh ]] || source $HOME/.p10k.zsh
'
p10k_instant_prompt='
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
'

echo $pt >> $HOME/.bashrc
echo $p10k_instant_prompt$original_zshrc$p10k_apply_config$pt > $HOME/.zshrc

echo "======Enjoy!======"

zsh