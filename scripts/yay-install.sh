#!/usr/bin/env bash

# yay-install.sh - Yay AUR Helper Installer
# Author: CornWorld(https://github.com/CornWorld)

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

# Function to check for required commands
check_requirements() {
    local required_cmds=("git" "sudo" "pacman")
    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            error "Required command '$cmd' not found. Please install it first."
        fi
    done
}

# Ensure the script is not run as root
if [[ "$(id -u)" -eq 0 ]]; then
    error "This script must not be run as root."
fi

# Display welcome message
echo -e "${BOLD}===============================================${NC}"
echo -e "${BOLD}          Yay AUR Helper Installer            ${NC}"
echo -e "${BOLD}===============================================${NC}"
echo ""
info "This script will install yay, an AUR helper for Arch Linux."
echo ""

# Check requirements
check_requirements

# Set build directory
BUILD_DIR="$HOME/.cache/yay/yay"
info "Using build directory: ${BUILD_DIR}"

# Create build directory if it doesn't exist
if [[ ! -d "$BUILD_DIR" ]]; then
    info "Creating build directory..."
    mkdir -p "$BUILD_DIR" || error "Failed to create build directory."
fi

# Prompt the user for their location
echo ""
echo -e "${BOLD}Please select your location:${NC}"
echo "1. Chinese Mainland"
echo "2. Other"
read -p "Enter your choice (1 or 2): " place

# Define GitHub mirror for Chinese users
GITHUB_MIRROR=""
if [[ "$place" == "1" ]]; then
    echo ""
    echo -e "${BOLD}GitHub Mirror Selection for Chinese Mainland:${NC}"
    echo "1. https://hub.fastgit.xyz"
    echo "2. https://ghproxy.com/https://github.com"
    echo "3. Enter custom mirror"
    read -p "Enter your choice (1, 2 or 3): " mirror_choice
    
    case $mirror_choice in
        1)
            GITHUB_MIRROR="https://hub.fastgit.xyz"
            ;;
        2)
            GITHUB_MIRROR="https://ghproxy.com/https://github.com"
            ;;
        3)
            read -p "Enter your custom GitHub mirror URL (without trailing slash): " GITHUB_MIRROR
            ;;
        *)
            error "Invalid option. Please enter either '1', '2', or '3'."
            ;;
    esac
    
    info "Using GitHub mirror: ${GITHUB_MIRROR}"
elif [[ "$place" != "2" ]]; then
    error "Invalid option. Please enter either '1' or '2'."
fi

# Install necessary packages
info "Installing necessary packages: base-devel, go, git..."
sudo pacman -Sy base-devel go git --needed --noconfirm || error "Failed to install necessary packages."

# Clone or update yay repository
if [[ -d "${BUILD_DIR}/.git" ]]; then
    info "Yay repository already exists, updating..."
    cd "$BUILD_DIR" || error "Failed to change directory to '${BUILD_DIR}'."
    git pull || error "Failed to update Yay repository."
else
    info "Cloning Yay repository..."
    git clone https://aur.archlinux.org/yay.git --depth 1 "$BUILD_DIR" || error "Failed to clone Yay repository."
    cd "$BUILD_DIR" || error "Failed to change directory to '${BUILD_DIR}'."
fi

# Modify PKGBUILD for Chinese users if needed
if [[ -n "$GITHUB_MIRROR" ]]; then
    info "Modifying PKGBUILD for Chinese Mainland users..."
    
    # Create a backup of the original PKGBUILD
    cp PKGBUILD PKGBUILD.orig
    
    # Modify the PKGBUILD file to replace GitHub URLs and add GOPROXY
    sed -i "s|https://github.com/|${GITHUB_MIRROR}/|g" PKGBUILD
    
    # Add GOPROXY to the build() function
    awk '{
        print $0;
        if ($0 ~ /^build\(\)/) {
            print "  export GOPROXY=https://goproxy.cn,direct";
        }
    }' PKGBUILD.orig > PKGBUILD.new
    
    mv PKGBUILD.new PKGBUILD
    
    info "PKGBUILD modified for Chinese Mainland."
fi

# Build and install yay
info "Building and installing yay..."
makepkg -si --noconfirm || error "Failed to build and install yay."

# Verify installation
if command -v yay &> /dev/null; then
    success "Yay has been successfully installed!"
    yay_version=$(yay --version | head -n 1)
    info "Installed version: ${yay_version}"
else
    error "Yay installation verification failed. Please check for errors."
fi

# Display post-installation information
echo ""
echo -e "${BOLD}===============================================${NC}"
echo -e "${BOLD}          Post-Installation Information        ${NC}"
echo -e "${BOLD}===============================================${NC}"
echo ""
info "To use yay, simply type 'yay -S package-name'"
info "To update all packages (including AUR): yay -Syu"
info "To search for packages: yay -Ss search-term"
info "For more help, type: yay -h"
echo ""
info "Build directory: ${BUILD_DIR}"
info "You can safely keep this directory for future updates."
echo ""
success "Thank you for using this installer!"
