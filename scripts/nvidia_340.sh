#!/bin/bash
#
# This script depends on the following User Configured Global Variables defined
# in config.sh:
#
# - LINUX_VERSION
# - SYSTEM_ROOT
#
# Script Assumptions:
# - x86_64 architecture
# - 64-bit driver installation

INSTALL_NVIDIA_DKMS="true"
INSTALL_NVIDIA_OPENCL="true"

set -e

# Base directory
export BASE_DIR=$(realpath $(dirname "$0"))

# Create a staging directory to store and process the drivers and patch files
STAGING_DIR="${BASE_DIR}/staging"
mkdir -p "${STAGING_DIR}"

# Source package
DRIVER_VERSION="340.108"
PKG="NVIDIA-Linux-x86_64-${DRIVER_VERSION}-no-compat32"
DRIVER_URL="https://us.download.nvidia.com/XFree86/Linux-x86_64/${DRIVER_VERSION}/${PKG}.run"
EXPECTED_DRIVER_HASH="6538bbec53b10f8d20977f9b462052625742e9709ef06e24cf2e55de5d0c55f1620a4bb21396cfd89ebc54c32f921ea17e3e47eaa95abcbc24ecbd144fb89028"

# Source patch files
AUR_PATCHES_URL="https://aur.archlinux.org/cgit/aur.git/snapshot/nvidia-340xx.tar.gz"

# Set paths/names for driver assets
UNPATCHED_DRIVER="${STAGING_DIR}/NVIDIA-Linux-x86_64-340.108.run"
DRIVER_EXTRACTION_DIR="${STAGING_DIR}/NVIDIA-Linux-x86_64-340.108"

# Determine the numeric kernel version for named instances of LINUX_VERSION
if [[ "${LINUX_VERSION}" = "linux" ]] || [[ "${LINUX_VERSION}" = "linux-lts" ]] || [[ "${LINUX_VERSION}" = "linux-mainline" ]]; then
	KERNEL_VERSION=$(xbps-query -R "${LINUX_VERSION}" | grep -oP "pkgver: ${LINUX_VERSION}-\K[^_]+" | awk -F. '{print $1"."$2}')
else
	KERNEL_VERSION=$(echo "${LINUX_VERSION}" | sed 's/linux//')
fi

# Set path, name, and description for patched driver assets
PATCHED_DRIVER="${DRIVER_EXTRACTION_DIR}-patched-for-kernel-${KERNEL_VERSION}.run"
PATCHED_DRIVER_DESCRIPTION="NVIDIA driver 340.108 patched for kernel ${KERNEL_VERSION}"

# Ensure the dependencies of this script are satisfied
declare -a DEV_PACKAGES=("patch" "wget" "tar")
xbps-install -Sy "${DEV_PACKAGES[@]}"

# Ensure the dependencies of the Nvidia drivers exist on the Void installation
#declare -a INSTALLATION_PACKAGES=("libglvnd" "libvdpau" "libglapi")
#xbps-install -Sy -r "${SYSTEM_ROOT}" "${INSTALLATION_PACKAGES[@]}"

if [[ ! -f "${UNPATCHED_DRIVER}" ]]; then
	echo "Downloading the NVIDIA driver..."
	wget -O "${UNPATCHED_DRIVER}" "${DRIVER_URL}"
fi

# Verify the driver's integrity
echo "Verifying driver integrity..."
DRIVER_HASH=$(b2sum "${UNPATCHED_DRIVER}" | cut -f 1 -d " ")
if [[ "${EXPECTED_DRIVER_HASH}" != "${DRIVER_HASH}" ]]; then
	echo "Error: The driver's hash doesn't match the expected value. Aborting."
	exit 1
fi

# Download and extract the AUR patches to the staging directory
wget -O "${STAGING_DIR}/nvidia-340xx.tar.gz" "${AUR_PATCHES_URL}"
tar xvf "${STAGING_DIR}/nvidia-340xx.tar.gz" -C "${STAGING_DIR}"

# Extract the NVIDIA driver
chmod +x "${UNPATCHED_DRIVER}"
"${UNPATCHED_DRIVER}" --extract-only --target "${DRIVER_EXTRACTION_DIR}"

# Change into the driver directory
pushd "${DRIVER_EXTRACTION_DIR}"

# Incrementally apply patches up to LINUX_VERSION
for patch_file in $(ls ${STAGING_DIR}/nvidia-340xx/0*.patch | sort); do
	# Extract version number from the patch filename
	patch_version=${patch_file##*-}
	patch_version=${patch_version%.patch}

	# Check if patch_version is less than or equal to KERNEL_VERSION
	if [[ $(echo -e "$KERNEL_VERSION\n$patch_version" | sort -V | head -n1) == $patch_version ]]; then
		echo "Applying patch for kernel $patch_version..."
		patch -Np1 <"$patch_file"
	fi

	if [[ "${patch_version}" == "${KERNEL_VERSION}" ]]; then
		break
	fi
done

# X driver
install -m 755 nvidia_drv.so "${SYSTEM_ROOT}/usr/lib/xorg/modules/drivers"

# GLX extension module for X
mkdir -p "${SYSTEM_ROOT}/usr/lib/nvidia/xorg/"
install -m 755 "libglx.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/nvidia/xorg/"
ln -sf "libglx.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/nvidia/xorg/libglx.so.1"
ln -sf "libglx.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/nvidia/xorg/libglx.so"

# Create Xorg config
cat <<'EOF' >"${SYSTEM_ROOT}/etc/X11/xorg.conf.d/20-nvidia.conf"
Section "Files"
  ModulePath   "/usr/lib/nvidia/xorg"
  ModulePath   "/usr/lib/xorg/modules"
EndSection

Section "Device"
  Identifier "Nvidia Card"
  Driver "nvidia"
  VendorName "NVIDIA Corporation"
EndSection

Section "ServerFlags"
  Option "IgnoreABI" "1"
EndSection
EOF

# OpenGL
install -m 755 "libnvidia-glcore.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/"
ln -sf "libnvidia-glcore.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/libnvidia-glcore.so"

install -m 755 "libGL.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/"
ln -sf "libGL.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/libGL.so.1"

install -m 755 "libEGL.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/"
ln -sf "libEGL.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/libEGL.so.1"

install -m 755 "libGLESv1_CM.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/"
ln -sf "libGLESv1_CM.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/libGLESv1_CM.so.1"

install -m 755 "libGLESv2.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/"
ln -sf "libGLESv2.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/libGLESv2.so.2"

# Some programs link to these libglvnd links
ln -sf "libGL.so.1" "${SYSTEM_ROOT}/usr/lib/libOpenGL.so.0"
ln -sf "libGL.so.1" "${SYSTEM_ROOT}/usr/lib/libGLX.so.0"

# VDPAU
install -m 755 "libvdpau_nvidia.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/vdpau/"
ln -sf "libvdpau_nvidia.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/vdpau/libvdpau_nvidia.so"
ln -sf "libvdpau_nvidia.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/vdpau/libvdpau_nvidia.so.1"

# Misc libraries
install -m 755 "tls/libnvidia-tls.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/"
ln -sf "libnvidia-tls.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/libnvidia-tls.so"

install -m 755 "libnvidia-cfg.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/"
ln -sf "libnvidia-cfg.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/libnvidia-cfg.so"
ln -sf "libnvidia-cfg.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/libnvidia-cfg.so.1"

install -m 755 "libnvidia-ml.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/"
ln -sf "libnvidia-ml.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/libnvidia-ml.so"
ln -sf "libnvidia-ml.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/libnvidia-ml.so.1"

install -m 755 "libnvidia-encode.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/"
ln -sf "libnvidia-encode.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/libnvidia-encode.so"
ln -sf "libnvidia-encode.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/libnvidia-encode.so.1"

install -m 755 "libnvidia-ifr.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/"
ln -sf "libnvidia-ifr.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/libnvidia-ifr.so"
ln -sf "libnvidia-ifr.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/libnvidia-ifr.so.1"

install -m 755 "libnvidia-fbc.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/"
ln -sf "libnvidia-fbc.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/libnvidia-fbc.so"
ln -sf "libnvidia-fbc.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/libnvidia-fbc.so.1"

install -m 755 "libnvidia-glsi.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/"

# CUDA
install -m 755 "nvidia-cuda-mps-control" "${SYSTEM_ROOT}/usr/bin/"
install -m 755 "nvidia-cuda-mps-server" "${SYSTEM_ROOT}/usr/bin/"
gunzip -c "nvidia-cuda-mps-control.1.gz" >"${SYSTEM_ROOT}/usr/share/man/man1/nvidia-cuda-mps-control.1"

install -m 755 "libcuda.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/"
ln -sf "libcuda.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/libcuda.so"
ln -sf "libcuda.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/libcuda.so.1"

install -m 755 "libnvcuvid.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/"
ln -sf "libnvcuvid.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/libnvcuvid.so"
ln -sf "libnvcuvid.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/libnvcuvid.so.1"

# nvidia-xconfig
install -m 755 "nvidia-xconfig" "${SYSTEM_ROOT}/usr/bin/"
gunzip -c "nvidia-xconfig.1.gz" >"${SYSTEM_ROOT}/usr/share/man/man1/nvidia-xconfig.1"

# nvidia-settings
install -m 755 "nvidia-settings" "${SYSTEM_ROOT}/usr/bin/"
gunzip -c "nvidia-settings.1.gz" >"${SYSTEM_ROOT}/usr/share/man/man1/nvidia-settings.1"
install -m 644 "nvidia-settings.desktop" "${SYSTEM_ROOT}/usr/share/applications/"
install -m 644 "nvidia-settings.png" "${SYSTEM_ROOT}/usr/share/pixmaps/"
sed -e 's:__UTILS_PATH__:/usr/bin:' \
	-e 's:__PIXMAP_PATH__:/usr/share/pixmaps:' \
	-i "${SYSTEM_ROOT}/usr/share/applications/nvidia-settings.desktop"

# nvidia-bug-report
install -m 755 "nvidia-bug-report.sh" "${SYSTEM_ROOT}/usr/bin/nvidia-bug-report"
install -m 755 "nvidia-debugdump" "${SYSTEM_ROOT}/usr/bin/"

# nvidia-smi
install -m 755 "nvidia-smi" "${SYSTEM_ROOT}/usr/bin/"
gunzip -c "nvidia-smi.1.gz" >"${SYSTEM_ROOT}/usr/share/man/man1/nvidia-smi.1"

# License and documentation.
mkdir -p "${SYSTEM_ROOT}/usr/share/licenses/NVIDIA/"
install -m 644 "LICENSE" "${SYSTEM_ROOT}/usr/share/licenses/NVIDIA/"
install -m 644 "README.txt" "${SYSTEM_ROOT}/usr/share/doc/NVIDIA/README"
install -m 644 "NVIDIA_Changelog" "${SYSTEM_ROOT}/usr/share/doc/NVIDIA/"

if [[ "${INSTALL_NVIDIA_DKMS}" = "true" ]]; then
	echo "Installing nvidia340-dkms..."

	# Ensure dkms and linux headers are installed
	xbps-install -Sy -r "${SYSTEM_ROOT}" dkms "${LINUX_VERSION}-headers"

	local COMPLETE_KERNEL_VERSION=$(chroot "${SYSTEM_ROOT}" xbps-query -l | grep -E "linux${KERNEL_VERSION}-[0-9]+" | grep -v headers | awk '{print $2}' | cut -d- -f2)

	# Set up the source for DKMS
	install -d "${SYSTEM_ROOT}/usr/src/nvidia-${DRIVER_VERSION}"
	cat "kernel/uvm/dkms.conf.fragment" >>"kernel/dkms.conf"
	cp -r kernel/* "${SYSTEM_ROOT}/usr/src/nvidia-${DRIVER_VERSION}"

	# Set up module loading configuration
	install -Dm644 /dev/null "${SYSTEM_ROOT}/usr/lib/modules-load.d/nvidia.conf"
	echo "nvidia" >"${SYSTEM_ROOT}/usr/lib/modules-load.d/nvidia.conf"

	install -Dm644 /dev/null "${SYSTEM_ROOT}/usr/lib/modules-load.d/nvidia-uvm.conf"
	echo "nvidia-uvm" >"${SYSTEM_ROOT}/usr/lib/modules-load.d/nvidia-uvm.conf"

	chroot "${SYSTEM_ROOT}" dkms add -m nvidia -v "${DRIVER_VERSION}" -k "${COMPLETE_KERNEL_VERSION}"
	chroot "${SYSTEM_ROOT}" dkms build -m nvidia -v "${DRIVER_VERSION}" -k "${COMPLETE_KERNEL_VERSION}"
	chroot "${SYSTEM_ROOT}" dkms install -m nvidia -v "${DRIVER_VERSION}" -k "${COMPLETE_KERNEL_VERSION}"
fi

if [[ "${INSTALL_NVIDIA_OPENCL}" = "true" ]]; then
	echo "Installing nvidia340-opencl..."

	# Replaces libOpenCL
	xbps-install -Sy -r "${SYSTEM_ROOT}" ocl-icd

	install -m 644 "nvidia.icd" "${SYSTEM_ROOT}/etc/OpenCL/vendors"

	install -m 755 "libnvidia-compiler.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib"

	ln -sf "libnvidia-compiler.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/libnvidia-compiler.so"
	ln -sf "libnvidia-compiler.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/libnvidia-compiler.so.1"

	install -m 755 "libnvidia-opencl.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib"
	ln -sf "libnvidia-opencl.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/libnvidia-opencl.so"
	ln -sf "libnvidia-opencl.so.${DRIVER_VERSION}" "${SYSTEM_ROOT}/usr/lib/libnvidia-opencl.so.1"
fi

# Exit the driver directory
popd

# Blacklist the nouveau driver
echo "Blacklisting nouveau driver..."
echo "blacklist nouveau" >"${SYSTEM_ROOT}/etc/modprobe.d/disable-nouveau.conf"

# Disable the nouveau driver
chroot "${SYSTEM_ROOT}" rmmod nouveau || echo "Nouveau module not loaded."

# Omit drm dracut module
mkdir -p "${SYSTEM_ROOT}/usr/lib/dracut/dracut.conf.d"
echo "omit_dracutmodules+=\" drm \"" >"${SYSTEM_ROOT}/usr/lib/dracut/dracut.conf.d/99-nvidia.conf"

echo "Regenerating initramfs, please wait..."
chroot "${SYSTEM_ROOT}" dracut -f -q --regenerate-all

# Remove the installer and extracted folder after completion
echo "Cleaning up temporary installation assets..."
rm -rf "${STAGING_DIR}"

echo "Driver installation completed!"

exit 0
