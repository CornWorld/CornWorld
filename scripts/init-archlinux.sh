#!/usr/bin/bash

# Author: CornWorld(https://github.com/CornWorld)

# Description: Configure basic options on an initial archlinux, especially for this type(https://github.com/felixonmars/vps2arch).

if [[ "$(id -u)" -nq 0 ]]; then
    echo "Error: This script must be run as root."
    exit 1
fi

passwd
echo "Enter hostname:"
read hostname
hostnamectl set-hostname $hostname
echo "Enter username:"
read name
useradd $name
passwd $name
mkdir -p /home/$name/.ssh
chown -Rf $name:$name /home/$name
pacman -Syu
pacman -Sy --noconfirm sudo vim git
echo "$name ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers

echo "======Enjoy!======"