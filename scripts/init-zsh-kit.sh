#!/usr/bin/bash

# Author: CornWorld(https://github.com/CornWorld)

# Description: Install zsh + oh-my-zsh + powerlevel10k on a initial archlinux where bash is already installed.

GITHUB_PREFIX=https://github.com
GITHUB_PREFIX_CN=https://slink.ltd/https://github.com
# GITHUB_PREFIX_CN=https://hub.fgit.cf

echo "Please select your location:"
echo "1. Chinese Mainland"
echo "2. Other"
read -p "Enter your choice (1 or 2): " place
case $place in
    1)
        GITHUB_PREFIX=$GITHUB_PREFIX_CN
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
wget -t 0 -c -O $HOME/install-ohmyzsh.sh $GITHUB_PREFIX/ohmyzsh/ohmyzsh/raw/master/tools/install.sh
sed -i "s|https://github.com|$GITHUB_PREFIX|" $HOME/install-ohmyzsh.sh
if [[ -d "$HOME/.oh-my-zsh" ]]; then 
    mv $HOME/.oh-my-zsh $HOME/.oh-my-zsh_backup_$RANDOM
fi
export RUNZSH=no
sh $HOME/install-ohmyzsh.sh 
rm $HOME/install-ohmyzsh.sh

if [[ ! -f "$HOME/.oh-my-zsh/README.md" ]]; then 
    rm $HOME/.oh-my-zsh -rf
    echo "[Error] ohmyzsh install failed: Network error. Cleaned up..."
    exit -1
fi

# Install Powerlevel10k
git clone --depth=1 $GITHUB_PREFIX/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

# Confirm whether $HOME/.zshrc existed
if [[ -f "$HOME/.zshrc" ]]; then
    # Use grep and sed to set theme
    grep -q 'ZSH_THEME="powerlevel10k/powerlevel10k"' $HOME/.zshrc || sed -i 's|ZSH_THEME=".*"|ZSH_THEME="powerlevel10k/powerlevel10k"|' $HOME/.zshrc
else
    # If not existed, create and write
    echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' > $HOME/.zshrc 
fi

# Download .p10k.zsh and .dircolors to $HOME
wget -t 0 -c -O $HOME/.p10k.zsh $GITHUB_PREFIX/CornWorld/CornWorld/raw/master/.p10k.zsh
wget -t 0 -c -O $HOME/.dircolors $GITHUB_PREFIX/CornWorld/CornWorld/raw/master/.dircolors

original_zshrc=$(cat "$HOME/.zshrc")
echo "$original_zshrc" > "$HOME/.zshrc_backup_$RANDOM"

pt=$(cat <<-'EOF'
alias rm='rm -I --preserve-root'
alias chmod='chmod --preserve-root'
alias chown='chown --preserve-root'
alias chgrp='chgrp --preserve-root'
EOF
)

p10k_apply_config=$(cat <<-'EOF'
[[ ! -f $HOME/.p10k.zsh ]] || source $HOME/.p10k.zsh
EOF
)

p10k_instant_prompt=$(cat <<-'EOF'
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
EOF
)

echo -e "\n$pt\n" >> "$HOME/.bashrc"
echo -e "$p10k_instant_prompt\n$p10k_apply_config\n\n$original_zshrc\n\n$pt\n" > "$HOME/.zshrc"

echo "======Enjoy!======"

zsh