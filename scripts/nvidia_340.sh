#!/bin/bash
#
# This script depends on the following User Configured Global Variables defined
# in config.sh:
#
# - LINUX_VERSION
# - SYSTEM_ROOT

set -e

# Base directory
export BASE_DIR=$(realpath $(dirname "$0"))

# Create a staging directory to store and process the drivers and patch files
STAGING_DIR="$BASE_DIR/staging"
mkdir -p "$STAGING_DIR"

# Source URLs
DRIVER_URL="https://us.download.nvidia.com/XFree86/Linux-x86_64/340.108/NVIDIA-Linux-x86_64-340.108.run"
AUR_PATCHES_URL="https://aur.archlinux.org/cgit/aur.git/snapshot/nvidia-340xx.tar.gz"

# Expected blake2 hash of the NVIDIA driver for verification
EXPECTED_DRIVER_HASH="890d00ff2d1d1a602d7ce65e62d5c3fdb5d9096b61dbfa41e3348260e0c0cc068f92b32ee28a48404376e7a311e12ad1535c68d89e76a956ecabc4e452030f15"

# Set paths/names for driver assets
UNPATCHED_DRIVER="$STAGING_DIR/NVIDIA-Linux-x86_64-340.108.run"
DRIVER_EXTRACTION_DIR="$STAGING_DIR/NVIDIA-Linux-x86_64-340.108"

# Determine the numeric kernel version for named instances of LINUX_VERSION
if [ "$LINUX_VERSION" = "linux" ] || [ "$LINUX_VERSION" = "linux-lts" ] || [ "$LINUX_VERSION" = "linux-mainline" ]; then
	KERNEL_VERSION=$(xbps-query -R "$LINUX_VERSION" | grep -oP "pkgver: $LINUX_VERSION-\K[^_]+" | awk -F. '{print $1"."$2}')
else
	KERNEL_VERSION=$(echo "$LINUX_VERSION" | sed 's/linux//')
fi

# Set path, name, and description for patched driver assets
PATCHED_DRIVER="$DRIVER_EXTRACTION_DIR-patched-for-kernel-$KERNEL_VERSION.run"
PATCHED_DRIVER_DESCRIPTION="NVIDIA driver 340.108 patched for kernel $KERNEL_VERSION"

# Ensure the dependencies of this script are satisfied
declare -a DEV_PACKAGES=("patch" "wget")
xbps-install -Sy "${DEV_PACKAGES[@]}"

# Ensure the dependencies of the Nvidia drivers exist on the Void installation
declare -a INSTALLATION_PACKAGES=("libglvnd" "libvdpau" "libglapi")
xbps-install -Sy -r $SYSTEM_ROOT "${INSTALLATION_PACKAGES[@]}"

if [ ! -f "$UNPATCHED_DRIVER" ]; then
	echo "Downloading the NVIDIA driver..."
	wget -O "$UNPATCHED_DRIVER" "$DRIVER_URL"
fi

# Verify the driver's integrity
echo "Verifying driver integrity..."
DRIVER_HASH=$(b2sum "$UNPATCHED_DRIVER" | cut -f 1 -d " ")
if [ "$EXPECTED_DRIVER_HASH" != "$DRIVER_HASH" ]; then
	echo "Error: The driver's hash doesn't match the expected value. Aborting."
	exit 1
fi

# Download and extract the AUR patches to the staging directory
wget -O "$STAGING_DIR/nvidia-340xx.tar.gz" "$AUR_PATCHES_URL"
tar xvf "$STAGING_DIR/nvidia-340xx.tar.gz" -C "$STAGING_DIR"

# Extract the NVIDIA driver
chmod +x "$UNPATCHED_DRIVER"
"$UNPATCHED_DRIVER" --extract-only --target "$DRIVER_EXTRACTION_DIR"

# Incrementally apply patches up to LINUX_VERSION
pushd "$DRIVER_EXTRACTION_DIR"
for patch_file in $(ls $STAGING_DIR/nvidia-340xx/0*.patch | sort); do
	# Extract version number from the patch filename
	patch_version=${patch_file##*-}
	patch_version=${patch_version%.patch}

	# Check if patch_version is less than or equal to KERNEL_VERSION
	if [[ $(echo -e "$KERNEL_VERSION\n$patch_version" | sort -V | head -n1) == $patch_version ]]; then
		echo "Applying patch for kernel $patch_version..."
		patch -Np1 <"$patch_file"
	fi

	# If the patch version equals the kernel version, break out of loop after applying
	if [[ $patch_version == $KERNEL_VERSION ]]; then
		break
	fi
done
popd

# Repackage the patched driver
echo "Repackaging the patched driver..."
"$DRIVER_EXTRACTION_DIR/makeself.sh" \
	--target-os Linux \
	--target-arch x86_64 \
	"$DRIVER_EXTRACTION_DIR" \
	"$PATCHED_DRIVER" "$PATCHED_DRIVER_DESCRIPTION" \
	./nvidia-installer

# Move the repackaged driver to $SYSTEM_ROOT/tmp
echo "Moving repackaged driver to $SYSTEM_ROOT/tmp..."
mv "$PATCHED_DRIVER" "$SYSTEM_ROOT/tmp/"

# Blacklist the nouveau driver
echo "Blacklisting nouveau driver..."
echo "blacklist nouveau" >"$SYSTEM_ROOT/etc/modprobe.d/disable-nouveau.conf"

# Disable the nouveau driver
chroot "$SYSTEM_ROOT" rmmod nouveau || echo "Nouveau module not loaded."

# Run the repackaged driver installer from chroot environment
echo "Installing the repackaged NVIDIA driver..."
chroot "$SYSTEM_ROOT" sh "/tmp/$(basename "$PATCHED_DRIVER")" --silent

# Remove the installer and extracted folder after completion
echo "Cleaning up temporary installation assets..."
rm -rf "$SYSTEM_ROOT/tmp/$(basename "$PATCHED_DRIVER")"
rm -rf "$STAGING_DIR"

echo "Driver installation completed!"

exit 0
