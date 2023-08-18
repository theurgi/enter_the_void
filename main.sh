#!/bin/bash

source ./utils/index.sh
source ./config.sh

# Ensure the script is run as root
if [[ "$EUID" -ne 0 ]]; then
	echo "Please run as root"
	exit
fi

# Check if .env file exists
if [ -f .env ]; then
	source .env
fi

CONFIGS_DIR="./configs"

# Sync the package repository and update xbps.
xbps-install -Suy xbps

# Source each of the scripts you want to include
source ./scripts/base_install.sh
# source ./scripts/graphics.sh
source ./scripts/rust.sh
source ./scripts/mac.sh
source ./scripts/network.sh
source ./scripts/xorg.sh
source ./scripts/xfce.sh
# source ./scripts/nix.sh
source ./scripts/broadcom-wl-dkms.sh
source ./scripts/broadcom-wifi-fix.sh
source ./scripts/nvidia_340.sh
source ./scripts/mac_nvidia_fix.sh

# Installation cleanup
cleanup_and_reboot
