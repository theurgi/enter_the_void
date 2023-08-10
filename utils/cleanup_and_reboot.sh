#!/bin/bash

#  Notifies the user that the installation is complete and asks if they want to
#  script to unmount the system and reboot.
cleanup_and_reboot() {
	# Print a success message indicating the installation is complete
	echo ""
	echo -e "${GREEN}Installation complete!${NC}"
	echo ""

	# Ask the user if they would like to unmount and reboot
	echo -e "\nUnmount newly created Void installation and reboot? (y/n)\n"

	# Read user's answer
	read user_input

	# If the user chooses 'y', perform the cleanup and reboot
	if [[ $user_input == "y" ]]; then
		# Unmount the newly installed system's root volume
		# if it was mounted
		if [[ "$FILESYSTEM_MOUNTED" == "true" ]]; then
			# --recursive ensures that all sub-mounts are also unmounted
			umount --recursive "$SYSTEM_ROOT"
		fi

		# Deactivate all active logical volumes in the volume group, if LVM was setup
		if [[ "$LVM_SETUP" == "true" ]]; then
			# This ensures that the underlying physical volumes can be safely deactivated.
			vgchange -an
		fi

		# Close the LUKS encrypted partition if LUKS was setup.
		if [[ "$LUKS_SETUP" == "true" ]]; then
			# This ensures that the encrypted volume is safely closed before rebooting.
			cryptsetup luksClose "$VOLUME_NAME"
		fi

		# Reboot the system.
		reboot
	fi
}
