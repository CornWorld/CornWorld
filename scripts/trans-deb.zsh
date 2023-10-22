#!/bin/zsh

# Author: CornWorld(https://github.com/CornWorld)

# Ensure only one argument is passed
if [[ $# -ne 1 ]]; then
    echo "Error: This script requires exactly one argument."
    echo "Usage: $0 <argument>"
    exit 1
fi

# Check if 'debtap' command exists
if ! command -v debtap &> /dev/null; then
    echo "Error: 'debtap' command not found. Attempting to install..."

    # Check if 'yay' command exists
    if ! command -v yay &> /dev/null; then
        echo "Error: 'yay' command not found. Attempting to install..."
        if ! ./install-yay.zsh; then
            echo "Error: Failed to run 'install-yay.zsh'. Please check if the file exists and has execute permissions."
            exit 1
        fi
    fi
    # Ensure the script is not run as root
    if [[ "$(id -u)" -eq 0 ]]; then
        echo "Error: This script must not be run as root."
        exit 1
    fi

    # Install 'debtap'
    if ! yay -Syy debtap; then
        echo "Error: Failed to install 'debtap'. Please check your network connection and try again."
        exit 1
    fi

    # Update 'debtap'
    if ! sudo debtap -u; then
        echo "Error: Failed to update 'debtap'. Please check your network connection and try again."
        exit 1
    fi
fi

# Run 'debtap' with the provided argument
if ! debtap $1; then
    echo "Error: Failed to run 'debtap' with argument '$1'. Please check the argument and try again."
    exit 1
fi
