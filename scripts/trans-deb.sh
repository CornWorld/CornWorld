#!/usr/bin/env bash

# trans-deb.sh - Convert Debian packages to Arch Linux packages
# Author: CornWorld(https://github.com/CornWorld)
# Created: 2025-03-01 09:16:21 UTC
# Version: 2.0

# Set color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Functions for consistent output formatting
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

usage() {
    echo -e "${BOLD}USAGE${NC}"
    echo -e "  $0 <debian-package.deb>"
    echo
    echo -e "${BOLD}DESCRIPTION${NC}"
    echo -e "  Converts Debian/Ubuntu packages to Arch Linux packages"
    echo
    echo -e "${BOLD}OPTIONS${NC}"
    echo -e "  -h, --help      Show this help message and exit"
    echo -e "  -u, --update    Update debtap database"
    echo -e "  -v, --version   Show version information"
    echo
}

version() {
    echo -e "${BOLD}trans-deb.sh${NC} - Version 2.0"
    echo -e "Last updated: 2025-03-01"
    echo -e "Created by: CornWorld (https://github.com/CornWorld)"
}

# Check if running as root
if [[ "$(id -u)" -eq 0 ]]; then
    error "This script must NOT be run as root"
fi

# ==== First priority: Install debtap if needed ====

# Check if 'debtap' command exists and install if missing
install_debtap() {
    if ! command -v debtap &> /dev/null; then
        info "Installing debtap..."

        # Check and install yay if needed
        if ! command -v yay &> /dev/null; then
            warning "'yay' not found. Installing yay..."
            
            # Try to find install-yay.sh in current directory or script directory
            local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
            local yay_installer="${script_dir}/yay-install.sh"
            
            if [[ -f "./yay-install.sh" ]]; then
                yay_installer="./yay-install.sh"
            fi
            
            if [[ -f "$yay_installer" ]]; then
                info "Running $yay_installer..."
                if ! bash "$yay_installer"; then
                    error "Failed to install yay. Please install it manually"
                fi
            else
                # Direct installation if install-yay.sh is not found
                warning "install-yay.sh not found. Attempting direct installation..."
                
                # Create temporary directory
                local temp_dir=$(mktemp -d)
                info "Created temporary directory: $temp_dir"
                
                cd "$temp_dir" || error "Failed to change to temporary directory"
                
                # Clone yay repository
                info "Cloning yay repository..."
                if ! git clone https://aur.archlinux.org/yay.git; then
                    error "Failed to clone yay repository"
                fi
                
                # Build and install yay
                cd yay || error "Failed to change to yay directory"
                info "Building and installing yay..."
                if ! makepkg -si --noconfirm; then
                    error "Failed to build and install yay"
                fi
                
                # Clean up
                cd "$OLDPWD" || error "Failed to return to original directory"
                rm -rf "$temp_dir"
                
                success "yay installed successfully"
            fi
        fi

        # Install debtap
        info "Installing debtap using yay..."
        if ! yay -S --noconfirm debtap; then
            error "Failed to install debtap"
        fi
        
        # Update debtap database
        update_debtap
        
        success "debtap installed successfully"
    else
        info "debtap is already installed"
    fi
}

# Update debtap database
update_debtap() {
    info "Updating debtap database..."
    if ! sudo debtap -u; then
        warning "Failed to update debtap database. Continuing anyway..."
    else
        success "debtap database updated successfully"
    fi
}

# Install debtap first (before argument processing)
install_debtap

# ==== Process arguments ====

# Handle special flags and no arguments
if [[ $# -eq 0 ]]; then
    error "No arguments provided. Use -h or --help for usage information"
fi

# Process flags
case "$1" in
    -h|--help)
        usage
        exit 0
        ;;
    -u|--update)
        update_debtap
        exit 0
        ;;
    -v|--version)
        version
        exit 0
        ;;
esac

# Check if file exists
if [[ ! -f "$1" ]]; then
    error "File '$1' does not exist"
fi

# Check if file has .deb extension
if [[ "${1##*.}" != "deb" ]]; then
    warning "File '$1' does not have a .deb extension. It might not be a valid Debian package"
    read -p "Continue anyway? (y/n) " -n 1 -r REPLY
    echo
    if [[ "$REPLY" != "y" ]]; then
        info "Aborted by user"
        exit 0
    fi
fi

# Run debtap with the provided file
info "Converting $1 to Arch Linux package format..."
if ! debtap -q "$1"; then
    error "Failed to convert package"
fi

success "Package conversion completed successfully"

# Look for the generated package file
pkg_dir=$(dirname "$1")
pkg_base=$(basename "$1" .deb)
pkg_path=$(find "$pkg_dir" -name "${pkg_base}*.pkg.tar*" -printf "%T@ %p\n" | sort -n | tail -n 1 | cut -d' ' -f2-)

if [[ -n "$pkg_path" ]]; then
    info "Generated package: $pkg_path"
    
    # Ask if user wants to install the package
    read -p "Do you want to install this package now? (y/n) " -n 1 -r REPLY
    echo
    if [[ "$REPLY" == "y" ]]; then
        info "Installing package..."
        sudo pacman -U "$pkg_path" || warning "Installation failed"
    else
        info "Package not installed. You can install it later with 'sudo pacman -U $pkg_path'"
    fi
else
    warning "Could not locate generated package file"
fi

exit 0
