#!/bin/bash
#
# This script depends on the following User Configured Global Variables defined
# in env.sh:
#
# - LIBC
# - SYSTEM_ROOT
# - VOID_REPO (computed from LIBC)

# Validate user configuration
check_in_list "SYSTEM_ROOT" "/mnt"
check_in_list "LIBC" "glibc" "musl"

# Enable the nonfree repository
xbps-install -SyR $VOID_REPO -r $SYSTEM_ROOT void-repo-nonfree

# Install the broadcom-wl-dkms package
xbps-install -Sy -r $SYSTEM_ROOT broadcom-wl-dkms ${LINUX_VERSION}-headers

# Rebuild the kernel modules after installation
chroot $SYSTEM_ROOT dkms autoinstall

# Blacklist conflicting Broadcom drivers
local broadcom_wl_dkms_conf=(
	"blacklist b43"
	"blacklist b43legacy"
	"blacklist bcma"
	"blacklist brcmsmac"
	"blacklist ssb"
)

write_to_file broadcom_wl_dkms_conf \
	"$SYSTEM_ROOT/etc/modprobe.d/broadcom-wl-dkms.conf"
