#!/bin/bash

# Usage: enable_services dbus NetworkManager lightdm
enable_services() {
	# Iterate over each service passed as an argument
	for service in "$@"; do
		# Check if the service exists
		if [ -d "$SYSTEM_ROOT/etc/sv/$service" ]; then

			# Check if the service is already enabled
			if [ ! -L "$SYSTEM_ROOT/var/service/$service" ]; then
				echo "Enabling $service..."
				chroot $SYSTEM_ROOT ln -s /etc/sv/$service /var/service/
			else
				echo "Service $service is already enabled."
			fi
		else
			echo "Service $service not found, skipping..."
		fi
	done
}

# Usage: disable_services dbus NetworkManager lightdm
disable_services() {
	# Iterate over each service passed as an argument
	for service in "$@"; do
		# Check if the service exists
		if [ -d "$SYSTEM_ROOT/etc/sv/$service" ]; then

			# Check if the service is already enabled (symbolic link exists)
			if [ -L "$SYSTEM_ROOT/var/service/$service" ]; then
				echo "Disabling $service..."
				chroot $SYSTEM_ROOT rm /var/service/$service
			else
				echo "Service $service is already disabled."
			fi
		else
			echo "Service $service not found, skipping..."
		fi
	done
}
