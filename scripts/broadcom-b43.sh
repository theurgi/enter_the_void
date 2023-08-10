#!/bin/bash

# This script depends on the following User Configured Global Variables defined
# in env.sh:
#
# - SYSTEM_ROOT

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────── Script Functions ──────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

# Verify that the user provided configuration is valid.
check_user_config() {
	check_in_list "SYSTEM_ROOT" "/mnt"
}

# Checks if git is installed, and if not, installs it.
check_and_install_git() {
	if ! command -v git &>/dev/null; then
		echo "Git is not installed. Installing git..."
		xbps-install -Suy git
	else
		echo "Git is already installed."
	fi
}

install_b43() {
	# Switch to user because xbps-src cannot be used as root.
	su anon -c "
	cd
	# Clone the void-packages repository with minimal history for faster cloning.
	git clone --depth=1 https://github.com/void-linux/void-packages.git
	cd void-packages

	# Run the bootstrap setup to prepare the build environment.
	./xbps-src binary-bootstrap

	# Modify the configuration to allow building of restricted packages.
	echo XBPS_ALLOW_RESTRICTED=yes >>etc/conf

	# Build the b43-firmware package.
	./xbps-src pkg b43-firmware
	"

	# Install the built b43-firmware package to the chrooted system root as root
	# user.
	xbps-install -yR hostdir/binpkgs/nonfree -r $SYSTEM_ROOT b43-firmware
}

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────── Main Script Logic ──────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

check_user_config
check_and_install_git
install_b43
