#!/bin/bash
#
# This script depends on the following User Configured Global Variables defined
# in env.sh:
#
# - SYSTEM_ROOT
# - USERNAME

# Verify user config
check_in_list "SYSTEM_ROOT" "/mnt"
check_not_empty "USERNAME"

# Install packages
xbps-install -Sy -r $SYSTEM_ROOT nix

# Enables services
enable_services nix-daemon

# chroot to $SYSTEM_ROOT and run the following as $USERNAME
chroot $SYSTEM_ROOT su - $USERNAME -c \
	'nix-channel --add http://nixos.org/channels/nixpkgs-unstable nixpkgs'

# chroot to $SYSTEM_ROOT and run the following as $USERNAME
chroot $SYSTEM_ROOT su - $USERNAME -c 'nix-channel --update'

# Add this to the bashrc of $SYSTEM_ROOT/home/$USERNAME
write_to_file 'export PATH=$HOME/.nix-profile/bin:$PATH' \
	$SYSTEM_ROOT/home/$USERNAME/.bashrc

# Define an array of Nix packages to be installed
NIX_PACKAGES=("vscodium" "brave")

for pkg in "${NIX_PACKAGES[@]}"; do
	chroot $SYSTEM_ROOT su - $USERNAME -c "nix-env -iA nixpkgs.$pkg"
done
