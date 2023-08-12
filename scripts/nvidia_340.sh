#!/bin/bash
#
# This script depends on the following User Configured Global Variables defined
# in config.sh:
#
# - LINUX_VERSION
# - SYSTEM_ROOT

set -e

# Base directory and driver details
BASE_DIR=$(dirname "$0")
DRIVER_URL="https://us.download.nvidia.com/XFree86/Linux-x86_64/340.108/NVIDIA-Linux-x86_64-340.108.run"
UNPATCHED_DRIVER=$(basename "$DRIVER_URL")
EXTRACTED_UNPATCHED_DRIVER="${UNPATCHED_DRIVER%.run}"

# Expected blake2 hash of the NVIDIA driver for verification
EXPECTED_B2SUM="890d00ff2d1d1a602d7ce65e62d5c3fdb5d9096b61dbfa41e3348260e0c0cc068f92b32ee28a48404376e7a311e12ad1535c68d89e76a956ecabc4e452030f15"

# Determine the actual kernel version based on LINUX_VERSION
if [ "$LINUX_VERSION" = "linux" ] || [ "$LINUX_VERSION" = "linux-lts" ] || [ "$LINUX_VERSION" = "linux-mainline" ]; then
	KERNEL_VERSION=$(xbps-query -R "$LINUX_VERSION" | grep -oP "pkgver: $LINUX_VERSION-\K[^_]+" | awk -F. '{print $1"."$2}')
else
	KERNEL_VERSION=$(echo "$LINUX_VERSION" | sed 's/linux//')
fi

PATCH_FILE="NVIDIA-340xx/kernel-$KERNEL_VERSION.patch"

# Check if a patch exists for this kernel version
if [ ! -f "$PATCH_FILE" ]; then
	echo "Error: No patch available for kernel version $KERNEL_VERSION"
	exit 1
fi

PATCHED_DRIVER="$EXTRACTED_UNPATCHED_DRIVER-patched-kernel-$KERNEL_VERSION.run"
PATCHED_DRIVER_DESCRIPTION="NVIDIA driver 340.108 patched for kernel $KERNEL_VERSION"

# Install dependencies
declare -a dev_dependencies=("patch" "wget")
xbps-install -Sy "${dev_dependencies[@]}"

declare -a installation_dependencies=("libglvnd" "libvdpau" "libglapi")
xbps-install -Sy -r $SYSTEM_ROOT "${installation_dependencies[@]}"

# Change to the base directory
cd "$BASE_DIR"

# Download the driver if it's not already present
if [ ! -f "$UNPATCHED_DRIVER" ]; then
	echo "Downloading the NVIDIA driver..."
	wget "$DRIVER_URL"
fi

# Verify the driver's integrity
echo "Verifying driver integrity..."
B2SUM_HASH=$(b2sum "$UNPATCHED_DRIVER" | cut -f 1 -d " ")
if [ "$EXPECTED_B2SUM" != "$B2SUM_HASH" ]; then
	echo "Error: The driver's hash doesn't match the expected value. Aborting."
	exit 1
fi

# Make driver executable
chmod +x "$UNPATCHED_DRIVER"

# Extract
"$UNPATCHED_DRIVER" --extract-only

# Change to the extracted directory
cd "$EXTRACTED_UNPATCHED_DRIVER"

# Apply the patch to the extracted contents
echo "Patching the driver for kernel $KERNEL_VERSION..."
patch -Np1 -i "../$PATCH_FILE"

# Repackage the patched driver
echo "Repackaging the patched driver..."
./makeself.sh --target-os Linux --target-arch x86_64 "$EXTRACTED_UNPATCHED_DRIVER" "$PATCHED_DRIVER" "$PATCHED_DRIVER_DESCRIPTION" ./nvidia-installer

# Move the repackaged driver to $SYSTEM_ROOT/tmp
echo "Moving repackaged driver to $SYSTEM_ROOT/tmp..."
mv "$PATCHED_DRIVER" "$SYSTEM_ROOT/tmp/"

# Change back to base directory
cd $BASE_DIR

# Blacklist the nouveau driver
echo "Blacklisting nouveau driver..."
echo "blacklist nouveau" >"$SYSTEM_ROOT/etc/modprobe.d/disable-nouveau.conf"

# Disable the nouveau driver
chroot "$SYSTEM_ROOT" rmmod nouveau || echo "Nouveau module not loaded."

# Run the repackaged driver installer from chroot environment
echo "Installing the repackaged NVIDIA driver..."
chroot "$SYSTEM_ROOT" sh "/tmp/$PATCHED_DRIVER"

# Remove the installer and extracted folder after completion
rm -rf $SYSTEM_ROOT/tmp/$PATCHED_DRIVER

echo "Driver installation completed!"

exit 0
