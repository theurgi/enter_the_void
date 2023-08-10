#!/bin/bash
#
# This script depends on the following User Configured Global Variables defined
# in env.sh:
#
# - DESKTOP_ENVIRONMENT
# - DISPLAY_SERVER
# - FORCE_MODESETTING
# - SYSTEM_ROOT
#
# https://docs.voidlinux.org/config/graphical-session/xorg.html

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────── Script Functions ──────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

check_user_config() {
	check_in_list "DESKTOP_ENVIRONMENT" "xfce4"
	check_in_list "DISPLAY_SERVER" "xorg" "xorg-minimal"
	check_in_list "SYSTEM_ROOT" "/mnt"

	check_boolean "FORCE_MODESETTING"

}

# Installs necessary packages for Xorg.
# The 'xinit' package is installed to provide the 'startx' script.
install_packages() {
	# Array to accumulate the required packages.
	declare -a packages=("xinit")

	case "$DISPLAY_SERVER" in
	"xorg")
		packages+=("xorg")
		;;
	"xorg-minimal")
		packages+=("xorg-minimal")
		packages+=("xorg-fonts")
		;;
	*)
		echo "Unsupported DISPLAY_SERVER: $DISPLAY_SERVER"
		echo "This script only supports 'xorg' or 'xorg-minimal'"
		exit 1
		;;
	esac

	xbps-install -Suy -r $SYSTEM_ROOT "${packages[@]}"

}

force_modesetting() {
	# Create configuration directory if it doesn't exist
	mkdir -p $SYSTEM_ROOT/etc/X11/xorg.conf.d

	local modesetting_conf=(
		'Section "Device"'
		'    Identifier "GPU0"'
		'    Driver "modesetting"'
		'EndSection'
	)

	write_to_file modesetting_conf \
		"$SYSTEM_ROOT"/etc/X11/xorg.conf.d/10-modesetting.conf
}

# Sets up the ~/.xinitrc file and adds the startx command to ~/.bash_profile.
setup_xinitrc_and_bash_profile() {
	local start_cmd=""

	case "$DESKTOP_ENVIRONMENT" in
	"xfce4")
		start_cmd="startxfce4"
		;;
	#  TODO Installation scripts for these have not yet been implemented.
	# "awesome")
	# 	start_cmd="awesome"
	# 	;;
	# "gnome")
	# 	start_cmd="gnome-session"
	# 	;;
	# "kde5")
	# 	start_cmd="startkde"
	# 	;;
	*)
		echo "Unsupported DESKTOP_ENVIRONMENT: $DESKTOP_ENVIRONMENT"
		exit 1
		;;
	esac

	# Create ~/.xinitrc with the appropriate desktop environment command
	echo "exec $start_cmd" >"$SYSTEM_ROOT/root/.xinitrc"

	# Append the startx command to ~/.bash_profile
	echo "startx" >>"$SYSTEM_ROOT/root/.bash_profile"
}

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────── Main Script Logic ──────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

check_user_config
install_packages

if $FORCE_MODESETTING; then
	force_modesetting
fi

enable_services dbus
setup_xinitrc_and_bash_profile
