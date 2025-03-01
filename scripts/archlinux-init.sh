#!/usr/bin/bash

# Author: CornWorld(https://github.com/CornWorld)
# Updated: 2025-03-01 09:20:56 UTC

# Description: Configure basic options on an Arch Linux system
# Useful for both initial setup and environment repairs
# Especially for systems converted using vps2arch (https://github.com/felixonmars/vps2arch)

# Check if running as root
if [[ "$(id -u)" -ne 0 ]]; then
    echo "Error: This script must be run as root."
    exit 1
fi

# Set or reset root password
echo "Setting root password (press Enter to skip if already set):"
passwd || echo "Password unchanged, continuing..."

# Configure hostname if needed
echo "Enter hostname (press Enter to skip):"
read hostname
if [[ -n "$hostname" ]]; then
    hostnamectl set-hostname $hostname
    echo "Hostname set to: $hostname"
else
    echo "Hostname unchanged, continuing..."
fi

# Create or check user
echo "Enter username (press Enter to skip):"
read name
if [[ -n "$name" ]]; then
    # Check if user already exists
    if id "$name" &>/dev/null; then
        echo "User '$name' already exists, skipping creation."
    else
        useradd -m "$name"
        echo "User '$name' created."
    fi
    
    # Set password for user
    echo "Setting password for $name:"
    passwd $name
    
    # Create SSH directory if it doesn't exist
    if [[ ! -d "/home/$name/.ssh" ]]; then
        mkdir -p "/home/$name/.ssh"
        echo "SSH directory created."
    fi
    
    # Fix permissions
    chown -Rf $name:$name /home/$name
    echo "Home directory permissions fixed."
else
    echo "No username provided, continuing..."
fi

# Update system
echo "Updating system packages..."
pacman -Syu --noconfirm || echo "Update encountered issues, continuing..."

# Install essential packages if not already installed
echo "Installing essential packages..."
pacman -Sy --needed --noconfirm sudo vim git

# Configure sudo access
if [[ -n "$name" ]]; then
    if ! grep -q "$name ALL=(ALL:ALL) NOPASSWD: ALL" /etc/sudoers; then
        echo "$name ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers
        echo "Sudo access configured for $name."
    else
        echo "Sudo access already configured for $name."
    fi
fi

# Fix SSH and session timeout settings
echo "Fixing SSH and session timeout settings..."
sed -i 's/^export TMOUT=.*/export TMOUT=0/' /etc/profile
if ! grep -q "export TMOUT=0" /etc/profile; then
    echo "export TMOUT=0" >> /etc/profile
fi

# Configure SSH settings only if they're not already set
if ! grep -q "^ClientAliveInterval 60" /etc/ssh/sshd_config; then
    sed -i "/#ClientAliveInterval/a\ClientAliveInterval 60" /etc/ssh/sshd_config
    sed -i "/#ClientAliveInterval/d" /etc/ssh/sshd_config
fi

if grep -q "^#ClientAliveCountMax" /etc/ssh/sshd_config; then
    sed -i '/ClientAliveCountMax/ s/^#//' /etc/ssh/sshd_config
fi

# Restart SSH service to apply changes
systemctl restart sshd.service

echo "======Environment Setup Complete!======"
