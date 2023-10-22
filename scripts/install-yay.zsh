#!/bin/zsh

# Author: CornWorld(https://github.com/CornWorld)

# Ensure the script is not run as root
if [[ "$(id -u)" -eq 0 ]]; then
    echo "Error: This script must not be run as root."
    exit 1
fi

# Prompt the user for their location
echo "Please select your location:"
echo "1. Chinese Mainland"
echo "2. Other"
read -p "Enter your choice (1 or 2): " place

# Install necessary packages
if ! sudo pacman -Sy base-devel go git --noconfirm; then
    echo "Error: Failed to install necessary packages. Please check your network connection and try again."
    exit 1
fi

case $place in
    1)
        # Set Go environment variables for Chinese Mainland users
        if ! go env -w GO111MODULE=on || ! go env -w GOPROXY=https://goproxy.cn,direct; then
            echo "Error: Failed to set Go environment variables. Please check your Go installation and try again."
            exit 1
        fi
        ;;
    2)
        # Do nothing for other users
        ;;
    *)
        # Handle invalid input
        echo "Error: Invalid option. Please enter either '1' or '2'."
        exit 1
        ;;
esac

# Clone, build, and install 'yay'
if ! git clone https://aur.archlinux.org/yay.git --depth 1 $HOME/yay-tmp; then
    echo "Error: Failed to clone 'yay' repository. Please check your network connection and try again."
    exit 1
fi

cd yay || ( echo "Error: Failed to change directory to 'yay'. The directory may not exist." && exit 1)

if ! makepkg -si; then
    echo "Error: Failed to build and install 'yay'. Please check your build environment and try again."
    exit 1
fi

# Cleanup
cd .. || ( echo "Error: Failed to change directory to parent directory. The directory may not exist." && exit 1)
rm -rf $HOME/yay-tmp
