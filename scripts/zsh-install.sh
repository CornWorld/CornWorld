#!/usr/bin/env bash

# init-zsh-kit.sh - Advanced ZSH Setup Script
# Author: CornWorld(https://github.com/CornWorld)
# Updated: 2025-03-01

# Description: Install zsh + zplug + powerlevel10k with additional plugins on Arch Linux

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Function for displaying messages
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check if running as root
if [[ "$(id -u)" -eq 0 ]]; then
    error "This script should not be run as root"
fi

# Display welcome message
echo -e "${BOLD}===============================================${NC}"
echo -e "${BOLD}          Advanced ZSH Setup Script           ${NC}"
echo -e "${BOLD}===============================================${NC}"
echo ""
info "This script will set up ZSH with zplug and various plugins."
info "Current user: ${USER:-$(whoami)}"
info "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# GitHub mirrors
GITHUB_PREFIX="https://github.com"
GITHUB_MIRRORS=(
    "https://slink.ltd/https://github.com"
    "https://ghproxy.com/https://github.com"
    "https://hub.fastgit.xyz"
    "https://hub.fgit.cf"
)

# Prompt user for location
echo -e "${BOLD}Please select your location:${NC}"
echo "1. Chinese Mainland"
echo "2. Other"
read -p "Enter your choice (1 or 2): " place
if [[ "$place" == "1" ]]; then
    echo ""
    echo -e "${BOLD}GitHub Mirror Selection for Chinese Mainland:${NC}"
    echo "1. https://slink.ltd/https://github.com"
    echo "2. https://ghproxy.com/https://github.com"
    echo "3. https://hub.fastgit.xyz"
    echo "4. https://hub.fgit.cf"
    echo "5. Enter custom mirror"
    
    read -p "Enter your choice (1-5): " mirror_choice
    
    case $mirror_choice in
        1) GITHUB_PREFIX="${GITHUB_MIRRORS[0]}" ;;
        2) GITHUB_PREFIX="${GITHUB_MIRRORS[1]}" ;;
        3) GITHUB_PREFIX="${GITHUB_MIRRORS[2]}" ;;
        4) GITHUB_PREFIX="${GITHUB_MIRRORS[3]}" ;;
        5) 
            read -p "Enter your custom GitHub mirror URL (without trailing slash): " custom_mirror
            GITHUB_PREFIX="$custom_mirror"
            ;;
        *) 
            warning "Invalid option. Using default: ${GITHUB_MIRRORS[0]}"
            GITHUB_PREFIX="${GITHUB_MIRRORS[0]}"
            ;;
    esac
fi

info "Using GitHub mirror: $GITHUB_PREFIX"

# Check for required commands and install them if missing
check_and_install() {
    for cmd in "$@"; do
        if ! command -v "$cmd" &> /dev/null; then
            info "Installing $cmd..."
            sudo pacman -S --needed --noconfirm "$cmd" || error "Failed to install $cmd"
        else
            info "$cmd is already installed"
        fi
    done
}

# Install necessary packages
info "Installing necessary packages..."
check_and_install git wget zsh curl fzf

# Backup existing zsh configuration
backup_configs() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local files=("$HOME/.zshrc" "$HOME/.zplug" "$HOME/.p10k.zsh")
    
    for file in "${files[@]}"; do
        if [[ -e "$file" ]]; then
            info "Backing up $file to ${file}_backup_${timestamp}"
            cp -r "$file" "${file}_backup_${timestamp}"
        fi
    done
}

backup_configs

# Set default shell to zsh
info "Setting ZSH as the default shell..."
if [[ "$SHELL" != "/bin/zsh" ]]; then
    chsh -s /bin/zsh || warning "Failed to change shell. Please run 'chsh -s /bin/zsh' manually."
else
    info "ZSH is already the default shell"
fi

# Install zplug
install_zplug() {
    info "Installing zplug..."
    ZPLUG_HOME="$HOME/.zplug"

    if [[ -d "$ZPLUG_HOME" ]]; then
        info "zplug is already installed, updating..."
        cd "$ZPLUG_HOME" && git pull
    else
        git clone --depth=1 "$GITHUB_PREFIX/zplug/zplug" "$ZPLUG_HOME" || error "Failed to install zplug"
    fi

    success "zplug installed successfully"
}

install_zplug

# Install Powerlevel10k and download custom configs
info "Installing powerlevel10k theme..."
P10K_DIR="$HOME/.powerlevel10k"

if [[ -d "$P10K_DIR" ]]; then
    info "powerlevel10k theme is already installed, updating..."
    cd "$P10K_DIR" && git pull
else
    git clone --depth=1 "$GITHUB_PREFIX/romkatv/powerlevel10k.git" "$P10K_DIR" || error "Failed to install powerlevel10k"
fi

# Download dircolors configuration
info "Downloading custom dircolors configuration..."
wget -t 3 -c -O "$HOME/.dircolors" "$GITHUB_PREFIX/CornWorld/CornWorld/raw/master/.dircolors" ||
    warning "Failed to download .dircolors, using default"

# Download p10k configuration
info "Downloading custom p10k configuration..."
wget -t 3 -c -O "$HOME/.p10k.zsh" "$GITHUB_PREFIX/CornWorld/CornWorld/raw/master/.p10k.zsh" ||
    warning "Failed to download .p10k.zsh, will use default"

# Create ZSH configuration file
info "Creating ZSH configuration file..."

# Create zshrc content - Fixed to prevent recursion issues
cat > "$HOME/.zshrc" << 'EOL'
# Increase function nesting limit to prevent recursion errors
FUNCNEST=100

# Enable Powerlevel10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Source zplug
source ~/.zplug/init.zsh

# Load powerlevel10k theme
zplug "romkatv/powerlevel10k", as:theme, depth:1

# Essential plugins - carefully ordered to prevent conflicts
zplug "zsh-users/zsh-completions"             # Additional completion definitions
zplug "zsh-users/zsh-autosuggestions"         # Fish-like autosuggestions
zplug "zsh-users/zsh-syntax-highlighting", defer:2  # Syntax highlighting
EOL

cat >> "$HOME/.zshrc" << 'EOL'
# Optional plugins - can be disabled if causing issues
if [[ "$ZSH_DISABLE_COMPLEX_PLUGINS" != "true" ]]; then
  zplug "zsh-users/zsh-history-substring-search" # Fish-like history search
#  zplug "hlissner/zsh-autopair"                 # Auto-close and delete matching delimiters
  zplug "MichaelAquilina/zsh-you-should-use"    # Reminds you of aliases
  zplug "supercrabtree/k"                       # Directory listings with git features
  zplug "agkozak/zsh-z"                         # Jump to directories based on frecency
else
  echo "Running with simplified plugin set (for compatibility)"
fi

# Install plugins if there are plugins that have not been installed
if ! zplug check --verbose; then
    printf "Install? [y/N]: "
    if read -q; then
        echo; zplug install
    fi
fi

# Load the plugins
zplug load

# Powerlevel10k configuration
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# History configuration
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
setopt sharehistory
setopt incappendhistory
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Custom aliases
alias ls='ls --color=auto'
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias rm='rm -I --preserve-root'
alias chmod='chmod --preserve-root'
alias chown='chown --preserve-root'
alias chgrp='chgrp --preserve-root'

# Directory colors
if [[ -f ~/.dircolors ]]; then
    eval "$(dircolors ~/.dircolors)"
fi

# Keybindings
if [[ "$ZSH_DISABLE_COMPLEX_PLUGINS" != "true" ]]; then
  bindkey '^[[A' history-substring-search-up 2>/dev/null
  bindkey '^[[B' history-substring-search-down 2>/dev/null
else
  # Basic history navigation
  bindkey '^[[A' up-line-or-history
  bindkey '^[[B' down-line-or-history
fi
EOL

cat >> "$HOME/.zshrc" << 'EOL'
# FZF configuration
if command -v fzf >/dev/null 2>&1; then
    [[ -f /usr/share/fzf/key-bindings.zsh ]] && source /usr/share/fzf/key-bindings.zsh
    [[ -f /usr/share/fzf/completion.zsh ]] && source /usr/share/fzf/completion.zsh
fi

# Local customizations
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# Troubleshooting mode
# If you encounter issues with zsh plugins, run:
# echo 'export ZSH_DISABLE_COMPLEX_PLUGINS=true' > ~/.zshrc.local
# This will disable some of the more complex plugins
EOL

# Update the GitHub mirror URLs in the zshrc file if user is in China
if [[ "$place" == "1" ]]; then
    sed -i "s|source ~/.zplug/init.zsh|export ZPLUG_GITHUB_PREFIX=\"$GITHUB_PREFIX\"\nsource ~/.zplug/init.zsh|" "$HOME/.zshrc"
fi

# Add aliases to .bashrc as well
info "Adding aliases to .bashrc..."
if [[ -f "$HOME/.bashrc" ]]; then
    cat >> "$HOME/.bashrc" << 'EOL'

# Custom aliases
alias ls='ls --color=auto'
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias rm='rm -I --preserve-root'
alias chmod='chmod --preserve-root'
alias chown='chown --preserve-root'
alias chgrp='chgrp --preserve-root'
EOL
fi

# Create a simplified zshrc file for troubleshooting
create_simple_zshrc() {
    info "Creating simplified zshrc for troubleshooting..."
    mkdir -p "$HOME/.zsh_backup"

    cat > "$HOME/.zsh_backup/simple_zshrc" << 'EOL'
# Simple ZSH configuration for troubleshooting
FUNCNEST=100

# Powerlevel10k
if [[ -f ~/.powerlevel10k/powerlevel10k.zsh-theme ]]; then
  source ~/.powerlevel10k/powerlevel10k.zsh-theme
fi

# Load p10k config
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# History
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
setopt sharehistory

# Basic aliases
alias ls='ls --color=auto'
alias ll='ls -la'
alias grep='grep --color=auto'
alias rm='rm -I --preserve-root'

# Directory colors
[[ -f ~/.dircolors ]] && eval "$(dircolors ~/.dircolors)"

# To use this simplified config:
# cp ~/.zsh_backup/simple_zshrc ~/.zshrc
EOL
}

create_simple_zshrc

# Create a shell script to fix zsh issues if they occur
cat > "$HOME/.fix-zsh.CornWorld.sh" << 'EOL'
#!/bin/bash
# Script to fix common ZSH issues
# Created: 2025-03-01
# Author: CornWorld

echo "ZSH Troubleshooter"
echo "==================="
echo
echo "This script will help you fix common ZSH issues."
echo

# Check for options
if [[ "$1" == "--simple" ]]; then
    echo "Installing simplified ZSH configuration..."
    if [[ -f "$HOME/.zsh_backup/simple_zshrc" ]]; then
        cp "$HOME/.zsh_backup/simple_zshrc" "$HOME/.zshrc"
        echo "Done. Please restart your shell."
    else
        echo "Simple configuration backup not found."
    fi
    exit 0
fi

if [[ "$1" == "--reset" ]]; then
    echo "Resetting ZSH configuration..."
    rm -rf "$HOME/.zplug/repos" 2>/dev/null
    echo "export ZSH_DISABLE_COMPLEX_PLUGINS=true" > "$HOME/.zshrc.local"
    echo "Done. Please run 'source ~/.zshrc' or restart your shell."
    exit 0
fi

if [[ "$1" == "--funcnest" ]]; then
    echo "Setting higher FUNCNEST value..."
    echo "export FUNCNEST=1000" >> "$HOME/.zshrc.local"
    echo "Done. Please run 'source ~/.zshrc' or restart your shell."
    exit 0
fi

echo "Available options:"
echo "  --simple   : Switch to a simplified ZSH configuration"
echo "  --reset    : Reset plugin repos and disable complex plugins"
echo "  --funcnest : Increase function nesting limit (fixes recursion errors)"
echo
echo "Usage: ./fix-zsh.sh [option]"
echo
echo "If you're experiencing the 'maximum nested function level reached' error,"
echo "try running: ./fix-zsh.sh --funcnest"
EOL

chmod +x "$HOME/fix-zsh.sh"

# Optional: Install nerd fonts for better powerline symbols
install_fonts() {
    info "Would you like to install Nerd Fonts for better icon support? (y/n)"
    read -r install_fonts_choice

    if [[ "$install_fonts_choice" == "y" || "$install_fonts_choice" == "Y" ]]; then
        local font_dir="$HOME/.local/share/fonts"
        mkdir -p "$font_dir"

        info "Installing MesloLGS NF font..."
        local font_urls=(
            "$GITHUB_PREFIX/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"
            "$GITHUB_PREFIX/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf"
            "$GITHUB_PREFIX/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf"
            "$GITHUB_PREFIX/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf"
        )

        for url in "${font_urls[@]}"; do
            local filename="${url##*/}"
            filename="${filename//%20/ }"
            wget -t 3 -c -O "$font_dir/$filename" "$url" || warning "Failed to download $filename"
        done

        fc-cache -f || warning "Failed to update font cache"
        success "Fonts installed successfully"
    fi
}

install_fonts

# Create a local zshrc for custom settings
touch "$HOME/.zshrc.local"
info "Created ~/.zshrc.local for your custom configurations"

# Additional convenience functions
cat >> "$HOME/.zshrc.local" << EOL
# Added by init-zsh-kit.sh on $(date '+%Y-%m-%d %H:%M:%S')
# User: ${USER:-$(whoami)}

# Useful functions
extract() {
  if [ -f \$1 ] ; then
    case \$1 in
      *.tar.bz2)   tar xjf \$1     ;;
      *.tar.gz)    tar xzf \$1     ;;
      *.bz2)       bunzip2 \$1     ;;
      *.rar)       unrar e \$1     ;;
      *.gz)        gunzip \$1      ;;
      *.tar)       tar xf \$1      ;;
      *.tbz2)      tar xjf \$1     ;;
      *.tgz)       tar xzf \$1     ;;
      *.zip)       unzip \$1       ;;
      *.Z)         uncompress \$1  ;;
      *.7z)        7z x \$1        ;;
      *)           echo "'\\$1' cannot be extracted via extract()" ;;
    esac
  else
    echo "'\\$1' is not a valid file"
  fi
}

# mkcd - create directory and cd into it
mkcd() {
  mkdir -p "\$@" && cd "\$1"
}
EOL

# Final information
echo ""
echo -e "${BOLD}===============================================${NC}"
echo -e "${BOLD}                Setup Complete                ${NC}"
echo -e "${BOLD}===============================================${NC}"
echo ""
success "ZSH setup is complete!"
info "To apply changes immediately, run: source ~/.zshrc"
info "Or log out and log back in to use the new shell."
echo ""
info "Configuration files:"
info "  - Main config: ~/.zshrc"
info "  - Custom local settings: ~/.zshrc.local"
info "  - Powerlevel10k config: ~/.p10k.zsh"
echo ""
info "When you start ZSH for the first time, zplug will prompt you to install the plugins."
echo ""
info "If you encounter the 'maximum nested function level reached' error:"
info "  Run: ~/fix-zsh.sh --funcnest"
echo ""
info "If you have other issues with plugins:"
info "  Run: ~/fix-zsh.sh --simple   (for a minimal configuration)"
info "  Run: ~/fix-zsh.sh --reset    (to reset and simplify plugins)"
echo ""
info "If the theme doesn't render correctly, make sure you have installed a Nerd Font"
info "and configured your terminal to use it."
echo ""
echo -e "${BOLD}Enjoy your advanced ZSH setup!${NC}"

# Optional: Automatically source zshrc if this script is being run from zsh
if [[ "$SHELL" == */zsh ]]; then
  info "Would you like to apply the changes immediately? (y/n)"
  read -r source_now
  if [[ "$source_now" == "y" || "$source_now" == "Y" ]]; then
    exec zsh -l
  fi
fi
