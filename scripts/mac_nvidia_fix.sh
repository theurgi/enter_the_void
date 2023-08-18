#!/bin/bash
#
# This script depends on the following User Configured Global Variables defined
# in config.sh:
#
# - SYSTEM_ROOT

# Identify the display address
DISPLAY_ADDR=$(lspci | grep -i "VGA compatible controller" | awk '{print $1}')

# Get the line number of the VGA compatible controller
LINE_NUM=$(lspci | grep -n "VGA compatible controller" | cut -d: -f1)

# Starting from the line above the VGA controller, loop backward to find the
# first PCI bridge
while ((LINE_NUM > 0)); do
	LINE_CONTENT=$(lspci | sed "${LINE_NUM}q;d")
	if [[ $LINE_CONTENT == *"PCI bridge"* ]]; then
		BRIDGE_ADDR=$(echo $LINE_CONTENT | awk '{print $1}')
		break
	fi
	((LINE_NUM--))
done

if [ -z "$BRIDGE_ADDR" ] || [ -z "$DISPLAY_ADDR" ]; then
	echo "Failed to identify the PCIe addresses."
	exit 1
fi

# Define the grub configuration directory
GRUB_CONF_DIR="/mnt/etc/grub.d"
CONF_FILE="$GRUB_CONF_DIR/01_enable_vga.conf"

# Create the 01_enable_vga.conf file
cat <<EOF >"$CONF_FILE"
setpci -s "$BRIDGE_ADDR" 3e.b=8
setpci -s "$DISPLAY_ADDR" 04.b=7
EOF

# Ensure the file is executable
chmod 755 "$CONF_FILE"

# Update grub configuration
chroot "${SYSTEM_ROOT}" update-grub
