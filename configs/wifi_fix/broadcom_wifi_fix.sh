#!/bin/bash

# Description: Workaround for Broadcom wireless interface issue post-reboot.
# This script briefly suspends the system and toggles the wireless interface,
# simulating a manual suspend-resume cycle, to bring networks back online.
# It ensures this operation is performed only once after each reboot.

# Path for the marker file
MARKER_FILE="/run/broadcom_wifi_fix.marker"

# Exit if the script has already been executed since the last boot.
if [ -f "$MARKER_FILE" ]; then
	exit 0
fi

# Initiate a brief system suspend.
rtcwake -m mem -s 5

# Disable and then enable the wireless interface.
rfkill block wifi
rfkill unblock wifi

# Create the marker file indicating the script's execution.
touch "$MARKER_FILE"
