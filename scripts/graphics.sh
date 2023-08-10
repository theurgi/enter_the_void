#!/bin/bash
#
# This script depends on the following User Configured Global Variables defined
# in env.sh:
#
# - DISPLAY_SERVER
# - GPU_VENDOR
# - LIBC
# - SYSTEM_ROOT
# - VOID_REPO (computed from LIBC)
#
# https://docs.voidlinux.org/config/graphical-session/index.html

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────── Script Functions ──────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

# TODO TEST why these drivers weren't installed

# Verify that the user provided configuration is valid.
check_user_config() {
	check_in_list "DISPLAY_SERVER" "xorg" "xorg-minimal"
	check_in_list "GPU_VENDOR" "amd" "ati" "intel" "nouveau" "nvidia"
	check_in_list "LIBC" "glibc" "musl"
	check_in_list "SYSTEM_ROOT" "/mnt"

}

# Install GPU drivers based on the user-specified vendors.
install_drivers() {
	# Array to accumulate the required driver packages.
	local -a drivers

	case "$GPU_VENDOR" in
	"amd" | "ati")
		drivers+=("linux-firmware-amd")

		# For OpenGL
		drivers+=("mesa-dri")

		# For Vulkan
		drivers+=("vulkan-loader")
		drivers+=("mesa-vulkan-radeon")

		# For Xorg
		if [[ $DISPLAY_SERVER == "xorg-minimal" ]]; then
			# Choose one of these Xorg driver packages to match your hardware and
			# comment the other.
			drivers+=("xf86-video-amdgpu")

			# drivers+=("xf86-video-ati")
		fi

		# Video acceleration
		drivers+=("mesa-vaapi")
		drivers+=("mesa-vdpau")
		;;

	"intel")
		drivers+=("linux-firmware-intel")

		# For OpenGl
		drivers+=("mesa-dri")

		# For Vulkan
		drivers+=("vulkan-loader")
		drivers+=("mesa-vulkan-intel")

		# Video acceleration
		drivers+=("intel-video-accel")
		drivers+=("xf86-video-intel")

		# TODO:
		#
		# The `LIBVA_DRIVER_NAME` environment variable is used to specify the
		# correct runtime acceleration driver to be used by the `intel-video-accel`
		# meta-package.
		# https://docs.voidlinux.org/config/graphical-session/graphics-drivers/intel.html#video-acceleration
		#
		# Troubleshooting:
		# https://docs.voidlinux.org/config/graphical-session/graphics-drivers/intel.html#troubleshooting
		;;

	"nvidia")
		# Proprietary Nvidia drivers don't support the musl C library.
		# https://github.com/NVIDIA/nvidia-installer/issues/10#issuecomment-573092418
		if [[ $LIBC == "glibc" ]]; then
			drivers+=("nvidia")

			# Legacy drivers:
			# drivers+=("nvidia470")
			# drivers+=("nvidia390")

			# 32-bit program support:
			# drivers+=("nvidia470-libs-32bit")
			# drivers+=("nvidia390-libs-32bit")
		fi
		;;

	"nouveau")
		# For OpenGl
		drivers+=("mesa-dri")

		# For Xorg
		if [[ $DISPLAY_SERVER == "xorg" || $DISPLAY_SERVER == "xorg-minimal" ]]; then
			drivers+=("xf86-video-nouveau")
		fi

		if [[ $LIBC == "glibc" ]]; then
			# Uncomment to for 32bit OpenGl support
			#drivers+=("mesa-dri-32bit")
		fi
		;;

	esac

	if [[ $DISPLAY_SERVER == "xorg-minimal" ]]; then
		# Uncomment to install Xorg video drivers meta-package:
		#drivers+=("xorg-video-drivers")
	fi

	# Proprietary Nvidia drivers require enabling the nonfree xbps package
	# repository.
	if [[ $GPU_VENDOR == "nvidia" ]]; then
		xbps-install -SyR $VOID_REPO -r $SYSTEM_ROOT void-repo-nonfree
	fi

	# Install all gathered driver packages.
	xbps-install -Sy -r $SYSTEM_ROOT "${drivers[@]}"
}

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────── Main Script Logic ──────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

check_user_config
install_drivers
