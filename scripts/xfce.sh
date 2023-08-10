#!/bin/bash
#
# This script depends on the following User Configured Global Variables defined
# in env.sh:
#
# - LOGIN_MANAGER
# - SYSTEM_ROOT

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────── Script Functions ──────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

check_user_config() {
	check_in_list "LOGIN_MANAGER" \
		"lightdm" "slim"

	check_in_list "SYSTEM_ROOT" "/mnt"

}

# Install XFCE desktop environment and login manager.
install_desktop_environment() {
	# Array to accumulate the required packages.
	declare -a packages

	# Base XFCE
	packages+=("xfce4")

	# Lightdm or slim login manager
	if [[ $LOGIN_MANAGER == "lightdm" ]]; then
		packages+=("lightdm")
		packages+=("lightdm-gtk3-greeter")
	elif [[ $LOGIN_MANAGER == "slim" ]]; then
		packages+=("slim")
	fi

	# Install all gathered packages.
	xbps-install -Suy -r $SYSTEM_ROOT "${packages[@]}"
}

# Configure login manager.
configure_login_manager() {
	if [[ $LOGIN_MANAGER == "lightdm" ]]; then
		enable_services dbus lightdm
	elif [[ $LOGIN_MANAGER == "slim" ]]; then
		enable_services dbus slim
	fi
}

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────── Main Script Logic ──────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

check_user_config
install_desktop_environment
configure_login_manager
