#!/bin/bash
#
# This script depends on the following User Configured Global Variables defined
# in env.sh:
#
# - SYSTEM_ROOT

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────── User Configuration ─────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

# Comment/uncomment the packages you want or don't want

# For trackpad
# If you want to use "xf86-input-mtrack", uncomment the next line
TRACKPAD_DRIVER="xf86-input-mtrack"
# If you want to use "xf86-input-synaptics", uncomment the next line
#TRACKPAD_DRIVER="xf86-input-synaptics"

# For fan control
# If you want to use "mbpfan", uncomment the next line
FAN_CONTROL="mbpfan"
# If you want to use "macfanctld", uncomment the next line
#FAN_CONTROL="macfanctld"

# For power save
# If you want to use "thermald" and "powertop", uncomment the next two lines
POWER_SAVE_PACKAGES=("thermald" "powertop")
# If you want to use "tlp", uncomment the next line
#POWER_SAVE_PACKAGES=("tlp")

# For battery
# If you want to use "acpi" and "cbatticon", uncomment the next two lines
BATTERY_PACKAGES=("acpi" "cbatticon")

# For display brightness
# If you want to use "light", uncomment the next line
BRIGHTNESS_PACKAGE="light"
# If you want to use "xbacklight", uncomment the next line
#BRIGHTNESS_PACKAGE="xbacklight"

# TODO find a package...
# For keyboard backlight
# KEYBOARD_BACKLIGHT_PACKAGE=""

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────── Script Functions ──────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

# Verify that the user provided configuration is valid.
check_user_config() {
	check_in_list "SYSTEM_ROOT" "/mnt"

}

install_packages() {

	# Install packages
	xbps-install -Suy -r $SYSTEM_ROOT \
		"${BATTERY_PACKAGES[@]}" \
		"${POWER_SAVE_PACKAGES[@]}" \
		$BRIGHTNESS_PACKAGE \
		$FAN_CONTROL \
		$TRACKPAD_DRIVER \
		alsa-utils \
		pulseaudio \
		pavucontrol

	# TODO if xfce: xfce4-pulseaudio-plugin
}

configure_packages() {
	# Configure Trackpad - xf86-input-mtrack
	if [ "$TRACKPAD_DRIVER" = "xf86-input-mtrack" ]; then

		# Create a dracut configuration file for the touchpad
		touch $SYSTEM_ROOT/etc/dracut.conf.d/10-touchpad.conf
		echo "add_drivers+=\" bcm5974 \"" >$SYSTEM_ROOT/etc/dracut.conf.d/10-touchpad.conf

		# Remove the 'usbmouse' kernel module and reload the 'bcm5974' kernel
		# module. Add these commands to 'rc.local', a shell script sourced in runit
		# stage 2 which can be used to specify configuration to be done prior to
		# login.
		#
		# See: https://docs.voidlinux.org/config/rc-files.html#rclocal
		echo -e "modprobe -r usbmouse\n\modprobe -r bcm5974\nmodprobe bcm5974" \
			>>$SYSTEM_ROOT/etc/rc.local

		# Create an Xorg configuration file for the touchpad and copy the
		# 50-mtrack.conf from the configs directory.
		local config_path=/etc/X11/xorg.conf.d

		mkdir -p $SYSTEM_ROOT/$config_path
		cp $CONFIGS_DIR/$config_path/50-mtrack.conf $SYSTEM_ROOT/$config_path/50-mtrack.conf
	fi
}

configure_services() {
	local -a services=("dbus" "$FAN_CONTROL")

	# Check if thermald should be enabled
	if [[ "${POWER_SAVE_PACKAGES[0]}" == "thermald" ]]; then
		services+=("thermald")
	fi

	enable_services "${services[@]}"
}

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────── Main Script Logic ──────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

check_user_config
install_packages
configure_packages
configure_services
