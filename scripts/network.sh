#!/bin/bash
#
# This script depends on the following User Configured Global Variables defined
# in env.sh:
#
# - NETWORK_UTILITY
# - SYSTEM_ROOT
#
# https://docs.voidlinux.org/config/network/index.html

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────── Script Functions ──────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

# Verify that the user provided configuration is valid.
check_user_config() {
	check_in_list NETWORK_UTILITY \
		"wpa_supplicant" "iwd" "NetworkManager" "connman"

	check_in_list SYSTEM_ROOT "/mnt"

}

# Install network utility and setup services based on the user-specified choice.
install_network_utility() {
	# Package and service names
	local package=""
	local -a services_to_enable
	local -a services_to_disable

	case "$NETWORK_UTILITY" in
	"wpa_supplicant")
		package="wpa_supplicant"
		services_to_enable=("wpa_supplicant")
		;;
	"iwd")
		package="iwd"
		services_to_enable=("iwd" "dbus")
		;;
	"NetworkManager")
		package="NetworkManager"
		services_to_enable=("NetworkManager" "dbus")
		services_to_disable=("dhcpcd" "wpa_supplicant" "wicd")
		;;
	"connman")
		package="connman"
		services_to_enable=("connmand")
		services_to_disable=("dhcpcd" "wpa_supplicant" "wicd")
		;;
	esac

	# Install the chosen network manager package
	xbps-install -Sy -r "$SYSTEM_ROOT" "$package"

	# Configure services
	enable_services "${services_to_enable[@]}"
	disable_services "${services_to_disable[@]}"

	# If you chose wpa_supplicant, create a minimal configuration file
	if [[ $NETWORK_UTILITY == "wpa_supplicant" ]]; then

		if [[ ! -f "$SYSTEM_ROOT"/etc/wpa_supplicant/wpa_supplicant.conf ]]; then
			local wpa_supplicant_conf=(
				"ctrl_interface=/run/wpa_supplicant"
				"update_config=1"
			)

			write_to_file wpa_supplicant_conf \
				"$SYSTEM_ROOT"/etc/wpa_supplicant/wpa_supplicant.conf
		fi
	elif [[ $NETWORK_UTILITY == "iwd" ]]; then
		local iwd_dir_path=/etc/iwd

		mkdir $SYSTEM_ROOT/$iwd_dir_path
		cp ../configs/$iwd_dir_path/main.conf $SYSTEM_ROOT/$iwd_dir_path/main.conf
	fi
}

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────── Main Script Logic ──────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

check_user_config
install_network_utility
