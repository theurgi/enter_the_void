#!/bin/bash

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────── User Configured Global Variables ──────────────────────
# ──────────────────────────────────────────────────────────────────────────────

# PACKAGE_FILE_PATH:
#
# A list of additional user packages to install during installation.
#
PACKAGE_FILE="./packages.txt"

# BASE_SYSTEM:
#
# The base meta-package which contains the minimal set of packages to install a
# usable Void system.
#
# To view the packages contained in each meta-package, see the 'depends' list of
# the package template file:
#
# base-system:
# https://github.com/void-linux/void-packages/blob/master/srcpkgs/base-system/template
#
# base-minimal:
# https://github.com/void-linux/void-packages/blob/master/srcpkgs/base-minimal/template
#
# Options: 'base-system' or 'base-minimal'
BASE_SYSTEM="base-system"

# LINUX_VERSION:
#
# The version of the linux kernel to install.
#
# Options: 'linux', 'linux-lts', 'linux-mainline', or a specific version number
# as 'linux<x>.<y>', for example, 'linux5.4' or 'linux6.1'.
LINUX_VERSION="linux-lts"

# USERNAME:
#
# The default username for the system.
# This can be modified to any desired username.
USERNAME="user"

# HOSTNAME:
#
# The name that the system uses to identify itself.
# This can be modified to any desired hostname.
HOSTNAME="void"

# VOLUME_NAME:
#
# The name assigned to the LUKS partition volume group and the prefix used for
# its logical volumes (swap, root, home, etc.)
#
# Example:
# If VOLUME_NAME="void", the disk layout would resemble:
#
# NAME              TYPE		MOUNTPOINT
# sda               disk
# ├─sda1            part    /boot/efi
# └─sda2            part
#   └─void          crypt
#     ├─void-swap   lvm     [SWAP]
#     ├─void-root   lvm     /
#     └─void-home   lvm     /home
#
VOLUME_NAME="$HOSTNAME"

# BOOT_PARTITION_SIZE:
#
# The size of the EFI system partition. This can be
# adjusted based on system requirements.
#
# More info: https://wiki.archlinux.org/title/EFI_system_partition
BOOT_PARTITION_SIZE="260M"

# ROOT_VOLUME_SIZE:
#
# The size of the root (/) logical volume.
# This can be adjusted based on system requirements and available disk space.
ROOT_VOLUME_SIZE="30G"

# SWAP_VOLUME_SIZE:
#
# The size of the swap logical volume.
# This can be adjusted based on system requirements and available RAM.
#
# More info: https://wiki.archlinux.org/title/Swap
SWAP_VOLUME_SIZE="8G"

# FS_TYPE:
#
# The type of file system to be used for the root and home logical
# volumes. This can be modified to any supported filesystem type like 'ext4',
# 'btrfs', 'xfs', etc.
FS_TYPE="ext4"

# LIBC:
#
# The C library implementation to be used by the system.
#
# Void Linux supports two C libraries, 'musl' and 'glibc'.
LIBC="glibc"

# Default Language:
#
# Possible options: 'en', 'es', 'fr', 'de', etc.
LANGUAGE="en"

# Default Timezone:
#
# Possible options: 'UTC', 'America/New_York', 'Asia/Kolkata', etc.
TIMEZONE="America/New_York"

# Default Locale:
#
# Possible options: 'en_US.UTF-8', 'es_ES.UTF-8', 'fr_FR.UTF-8', etc.
LOCALE="en_US.UTF-8"

# Default Keymap:
#
# Possible options: 'us', 'uk', 'de', 'fr', etc.
KEYMAP="us"

# Default User Groups:
#
# This list of groups the user will be added to upon
# creation. Modify to add or remove groups based on user requirements and system
# configuration.
#
# Possible options: 'wheel', 'floppy', 'cdrom', 'optical',
# 'audio', 'video', 'kvm', 'xbuilder', etc.
#
# Documentation: https://wiki.archlinux.org/title/Users_and_groups
USER_GROUPS="wheel,floppy,cdrom,optical,audio,video,kvm,xbuilder"

# ENABLE_FSTRIM:
#
# Enables or disables SSD TRIM.
# Set to 'true' to enable, 'false' to disable.
# More info: https://wiki.archlinux.org/title/Solid_state_drive#TRIM
#
# Please note there are security implications when enabling TRIM with LUKS:
# https://wiki.archlinux.org/title/Dm-crypt/Specialties#Discard/TRIM_support_for_solid_state_drives_(SSD)
ENABLE_FSTRIM="true"

# CPU_VENDOR: Specifies the vendor of the CPU in your system.
# Possible options: 'intel', 'amd'
CPU_VENDOR="intel"

# SYSTEM_ROOT:
#
# Specifies the root directory of the system where packages will be installed.
#
# This should be set to "/mnt" because all scripts currently assume the
# system is being installed from a live image.
SYSTEM_ROOT="/mnt"

# GPU_VENDOR:
#
# Specifies the vendor of the GPU in your system. If your vendor is Nvidia but
# you want to use open source drivers, select 'nouveau'.
#
# Options: 'amd', 'ati', 'intel', 'nouveau', 'nvidia'.
GPU_VENDOR="nvidia"

# DISPLAY_SERVER:
#
# Specifies the type of desktop environment to be used.
#
# Options: 'xorg', 'xorg-minimal', 'wayland'.
DISPLAY_SERVER="xorg-minimal"

# LOGIN_MANAGER:
#
# Specifies the type of login manager to be used.
#
# Options: 'lightdm', 'slim'.
LOGIN_MANAGER="lightdm"

# DESKTOP_ENVIRONMENT:
#
# The command to start the desired desktop environment.
# For example, it might be set to "startxfce4" if using the XFCE desktop environment.
#
# Other options include: "xfce4", "awesome", "gnome"
DESKTOP_ENVIRONMENT="xfce4"

# NETWORK_UTILITY:
#
# Specifies the network utility to be used.
#
# Options: 'wpa_supplicant', 'iwd', 'NetworkManager', 'connman'.
NETWORK_UTILITY="iwd"

# FORCE_MODESETTING:
#
# Specifies whether the system should use the modesetting driver as default.
# Modesetting is a generic Xorg driver that is used if no other dedicated
# driver for the system's graphics hardware is installed.
# Set to 'true' to force the use of modesetting driver.
FORCE_MODESETTING=false

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────── Computed Global Variables ──────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

# These variables are computed from User Configured Global Variables and should
# not be directly modified by the user.

# Based on the LIBC value, we determine the appropriate VOID_REPO.
VOID_REPO="https://repo-default.voidlinux.org/current$(
	[ "$LIBC" = "musl" ] && echo "/musl"
)"
