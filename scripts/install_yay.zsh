#!/bin/zsh

# Author: CornWorld

if [ "$(id -u)" -eq 0 ]; then
	echo "Err: not root only!"
	exit 1
fi

echo "Where you are?"
echo "1. Chinese Mainland"
echo "2. Other"

echo "[Input]: "
read place

sudo pacman -Sy base-devel go git

case $place in
    1)
        go env -w GO111MODULE=on
	go env -w GOPROXY=https://goproxy.cn,direct
	;;
    2)
        ;;
    *)
        echo "unexpected option"
        ;;
esac

git clone https://aur.archlinux.org/yay
cd yay
makepkg -si

