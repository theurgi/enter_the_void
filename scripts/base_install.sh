#!/bin/bash
#
# This script depends on the following User Configured Global Variables defined
# in env.sh:
#
# - USERNAME
# - HOSTNAME
# - VOLUME_NAME
# - BOOT_PARTITION_SIZE
# - ROOT_VOLUME_SIZE
# - SWAP_VOLUME_SIZE
# - FS_TYPE
# - LIBC
# - LANGUAGE
# - TIMEZONE
# - KEYMAP
# - USER_GROUPS
# - ENABLE_FSTRIM
# - CPU_VENDOR
# - VOID_REPO
# - SYSTEM_ROOT
# - BASE_SYSTEM
# - LINUX_VERSION
# - PACKAGE_FILE

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────── Global Script Variables ───────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

# This section contains global variables that are modified or referenced
# throughout this script. These variables are declared here for initialization
# and should not be modified by the user. All user configured variables should
# be configured in the config.sh file.

# This array accumulates any arguments that should be provided by GRUB to the
# default command line for the Linux kernel. Arguments may be added by
# functions throughout the script. The final array of argument strings will be
# added to the GRUB configuration file in the `configure_system` function near
# the end of the script.
#
# Here, the array is initialized with the "rd.lvm.vg" kernel argument which
# instructs the system to activate the specified LVM volume group at boot.
declare -a KERNEL_ARGS=("rd.lvm.vg=$VOLUME_NAME")

# Script event flags to be set when certain processes complete. These flags
# will be checked by the utils/cleanup_and_reboot script to determine the
# appropriate cleanup actions to take.
LUKS_SETUP=false
LVM_SETUP=false
FILESYSTEM_MOUNTED=false

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────── Script Functions ──────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

# Verify that the user provided configuration is valid.
check_user_config() {
	check_non_empty \
		"BOOT_PARTITION_SIZE" \
		"HOSTNAME" \
		"KEYMAP" \
		"LANGUAGE" \
		"LINUX_VERSION" \
		"ROOT_VOLUME_SIZE" \
		"SWAP_VOLUME_SIZE" \
		"TIMEZONE" \
		"USER_GROUPS" \
		"USERNAME" \
		"VOLUME_NAME"

	check_in_list "FS_TYPE" "ext4" "xfs" "btrfs" "f2fs"
	check_in_list "LIBC" "glibc" "musl"
	check_in_list "CPU_VENDOR" "intel" "amd"
	check_in_list "BASE_SYSTEM" "base-system" "base-minimal"

	check_boolean "ENABLE_FSTRIM"

	# Verify the chosen Linux version exists in the repository
	if ! package_exists $LINUX_VERSION; then
		echo "Error: $LINUX_VERSION not found in repository. Exiting."
		exit 1
	fi
}

# Function to select the target disk for the installation
select_disk() {
	# If TARGET_DISK is not already defined, prompt the user to select a disk.
	if [[ -z "$TARGET_DISK" ]]; then
		# An array to store the lines of disk information
		declare -a disk_lines

		# Get a list of suitable disks for installation (greater than 1GiB), excluding
		# loop devices and mapper devices, and store them in the array.
		mapfile -t disk_lines < <(fdisk -l | grep -v mapper | grep -v loop |
			grep -o '/.*GiB' | tr -d ' ')

		# Check if any suitable disks were found
		if [ ${#disk_lines[@]} -eq 0 ]; then
			echo -e "\n${RED}No suitable disks found for installation.${NC}\n" >&2
			return 1
		fi

		# Customize the prompt string for the select command
		PS3="❯ "
		printf "\n${CYAN}Select disk for installation: ${NC}\n\n"

		# Use the select command to generate a menu to choose from the disk_lines array
		select disk_info in "${disk_lines[@]}"; do
			# Check if a valid option was selected
			if [ -n "$disk_info" ]; then
				echo -e "\n${GREEN}Selected disk: $disk_info${NC}\n"
				# Extract the disk name from the selected line
				TARGET_DISK=$(echo "$disk_info" | sed 's/:.*$//')
				break
			else
				echo -e "\n${RED}Invalid choice, please try again.${NC}\n" >&2
			fi
		done

		# Check if a disk was selected
		if [[ -z "$TARGET_DISK" ]]; then
			echo -e "\n${RED}Disk selection was cancelled.${NC}\n" >&2
			return 1
		fi
	fi

	# Define the boot and LUKS partition names based on the selected disk
	if [[ "$TARGET_DISK" == *"sd"* ]]; then
		BOOT_PARTITION="${TARGET_DISK}1"
		LUKS_PARTITION="${TARGET_DISK}2"
	else
		# For other disks like nvme or mmc, add 'p' before partition number
		BOOT_PARTITION="${TARGET_DISK}p1"
		LUKS_PARTITION="${TARGET_DISK}p2"
	fi
}

# Prompt the user to enter passwords for the LUKS partition, the root user, and
# the primary user.
set_passwords() {
	declare -A password_descriptions

	password_descriptions=(
		["LUKS_PARTITION_PASSWORD"]="LUKS Partition"
		["ROOT_USER_PASSWORD"]="Root User"
		["USER_PASSWORD"]="User"
	)

	for item in "${!password_descriptions[@]}"; do
		if [ -z "${!item}" ]; then
			while true; do
				echo -e "${CYAN}Enter the ${password_descriptions[$item]} password:${NC}"
				read -s password

				echo -e "${CYAN}Confirm the ${password_descriptions[$item]} password:${NC}"
				read -s password_confirm

				if [ "$password" == "$password_confirm" ]; then
					declare -g "$item=$password"
					break
				else
					echo -e "${RED}Passwords do not match, please try again.${NC}"
				fi
			done
		fi
	done
}

# Create two partitions on the target disk.
create_partitions() {
	# 'label: gpt' sets the partition table type to GPT.
	#
	# ', %s, U, *' creates the first partition with a size of
	# $BOOT_PARTITION_SIZE, type U (EFI system), and bootable (*).
	#
	# ', , L' creates the second partition using the rest of the disk, with type L
	# (Linux filesystem).
	#
	# Pipe this script into sfdisk -q "$TARGET_DISK" to apply it to the target
	# disk without any prompts (-q).
	printf 'label: gpt\n, %s, U, *\n, , L\n' "$BOOT_PARTITION_SIZE" |
		sfdisk -q "$TARGET_DISK" &>/dev/null
}

# Set up encryption on a partition using LUKS.
setup_encryption() {
	# '-q' silences the confirmation prompt that would usually be displayed.
	#
	# '--type luks1' specifies that we want to use LUKS1 encryption type.
	echo $LUKS_PARTITION_PASSWORD | cryptsetup -q luksFormat --type luks1 $LUKS_PARTITION

	# Unlock the encrypted partition so that system can be installed to it.
	#
	# The partition will be available at /dev/mapper/$VOLUME_NAME.
	echo $LUKS_PARTITION_PASSWORD | cryptsetup luksOpen $LUKS_PARTITION $VOLUME_NAME

	# Set the script event flag.
	LUKS_SETUP=true
}

# Set up LVM (Logical Volume Manager) on the encrypted partition.
# More info on LVM: https://wiki.archlinux.org/title/LVM
setup_lvm() {
	# Creates a volume group named $VOLUME_NAME on /dev/mapper/$VOLUME_NAME, which is
	# the unlocked LUKS partition.
	vgcreate $VOLUME_NAME /dev/mapper/$VOLUME_NAME

	# Creates a logical volume named 'swap' of size $SWAP_VOLUME_SIZE in the
	# volume group $VOLUME_NAME.
	lvcreate --name swap -L $SWAP_VOLUME_SIZE $VOLUME_NAME

	# Creates a logical volume named 'root' of size $ROOT_VOLUME_SIZE in the
	# volume group $VOLUME_NAME.
	lvcreate --name root -L $ROOT_VOLUME_SIZE $VOLUME_NAME

	# lvcreate --name home -l 100%FREE $VOLUME_NAME creates a logical volume named
	# 'home' that occupies the remaining free space in the volume group $VOLUME_NAME.
	lvcreate --name home -l 100%FREE $VOLUME_NAME

	# Set the script event flag.
	LVM_SETUP=true
}

# Formats and mounts the partitions and logical volumes.
format_and_mount_filesystems() {

	# Format and mount the `root` logical volume.
	# `-q`: Quiet execution
	# `-L`: Set the volume label for the filesystem
	mkfs.$FS_TYPE -q -L root /dev/$VOLUME_NAME/root
	mount /dev/$VOLUME_NAME/root $SYSTEM_ROOT

	# Set up the `swap` logical volume as swap space.
	mkswap /dev/$VOLUME_NAME/swap

	# Format, create, and mount the `home` logical volume.
	mkfs.$FS_TYPE -q -L home /dev/$VOLUME_NAME/home
	mkdir -p $SYSTEM_ROOT/home
	mount /dev/$VOLUME_NAME/home $SYSTEM_ROOT/home

	# Format, create, and mount the boot partition.
	mkfs.vfat $BOOT_PARTITION
	mkdir -p $SYSTEM_ROOT/boot/efi
	mount $BOOT_PARTITION $SYSTEM_ROOT/boot/efi

	# Bind the live system's `dev`, `proc`, `sys`, and `run` directories to the
	# corresponding directories in $SYSTEM_ROOT, making the system's special file
	# systems available in the chroot environment.
	#
	# '--rbind': 'recursive bind mount' attaches each directory tree including
	# its submounts (recursive) to the target mount point.
	#
	# `--make-rslave`: Change the propagation type of the mount point to "slave".
	# For example, if something is mounted or unmounted in `/dev`, that change
	# will also happen in `$SYSTEM_ROOT/dev`. However, if something is mounted or
	# unmounted in `$SYSTEM_ROOT/dev`, that change will not propagate back to `/dev`.
	for dir in dev proc sys run; do
		mkdir -p $SYSTEM_ROOT/$dir
		mount --rbind /$dir $SYSTEM_ROOT/$dir
		mount --make-rslave $SYSTEM_ROOT/$dir
	done

	# Set the script event flag.
	FILESYSTEM_MOUNTED=true
}

# Install Void's core packages along with the necessary packages required by
# this installation script.
install_base_system() {
	local pkgs_particular_to_this_script=("cryptsetup" "grub-x86_64-efi" "lvm2")

	local diff_base_packages=""

	if [ "${BASE_SYSTEM}" == "base-system" ]; then
		diff_base_packages=$(get_diff_base_packages)
	fi

	# If the user configured LINUX_VERSION is not 'linux' (the Void default),
	# ignore 'linux' and mark it as a manually managed package.
	#
	# https://docs.voidlinux.org/config/kernel.html#removing-the-default-kernel-series
	if [ "$LINUX_VERSION" != "linux" ]; then
		echo "ignorepkg=linux" >>/etc/xbps.d/ignore.conf
		echo "ignorepkg=linux-headers" >>/etc/xbps.d/ignore.conf
		xbps-pkgdb -m manual linux-base
	fi

	echo y | xbps-install -SuyR ${VOID_REPO} -r ${SYSTEM_ROOT} \
		base-minimal $diff_base_packages \
		${LINUX_VERSION} ${LINUX_VERSION}-headers linux-base \
		${pkgs_particular_to_this_script[@]}
}

# Function to install user-provided packages
install_user_packages() {

	# Check if the file exists
	if [[ ! -f $PACKAGE_FILE ]]; then
		echo "The package file $PACKAGE_FILE does not exist."
		return 1
	fi

	# Array to hold valid package names
	local -a valid_packages=()

	# Read the file line by line
	while IFS= read -r line; do
		# Check if the package exists
		if package_exists "$line"; then
			# If it does, add it to the array
			valid_packages+=("$line")
		else
			# If it doesn't, print a warning
			echo "Warning: package $line does not exist and will be skipped."
		fi
	done <"$PACKAGE_FILE"

	# Install the valid packages
	xbps-install -SyR ${VOID_REPO} -r ${SYSTEM_ROOT} "${valid_packages[@]}"
}

# Generates the fstab ("file systems table") file using logical volume UUIDs.
#
# The fstab file is automatically read by the mount command during the boot
# process to determine the overall file system structure.
#
# More info: https://wiki.archlinux.org/title/fstab
generate_fstab() {
	# Root logical volume
	local root_uuid=$(blkid -s UUID -o value "/dev/$VOLUME_NAME/root")
	echo "UUID=$root_uuid / ext4 defaults 0 1" >>$SYSTEM_ROOT/etc/fstab

	# Home logical volume
	local home_uuid=$(blkid -s UUID -o value "/dev/$VOLUME_NAME/home")
	echo "UUID=$home_uuid /home ext4 defaults 0 2" >>$SYSTEM_ROOT/etc/fstab

	# Swap logical volume
	local swap_uuid=$(blkid -s UUID -o value "/dev/$VOLUME_NAME/swap")
	echo "UUID=$swap_uuid none swap defaults 0 0" >>$SYSTEM_ROOT/etc/fstab

	# Boot logical volume
	local boot_uuid=$(blkid -s UUID -o value "$BOOT_PARTITION")
	echo "UUID=$boot_uuid /boot/efi vfat defaults 0 2" >>$SYSTEM_ROOT/etc/fstab

}

# Modifies the GRUB bootloader configuration to support booting from
# an encrypted disk using LUKS (Linux Unified Key Setup).
configure_grub_for_luks() {
	local luks_uuid=$(blkid -s UUID -o value $LUKS_PARTITION)

	KERNEL_ARGS+=("rd.luks.uuid=$luks_uuid")

	echo "GRUB_ENABLE_CRYPTODISK=y" >>$SYSTEM_ROOT/etc/default/grub
}

# Create a cryptographic key file that is stored on the boot partition and can
# be used to unlock the LUKS partition without requiring the password to be
# entered twice.
setup_double_password_entry_avoidance() {
	# Create a 64 byte random key and store it in /boot/volume.key.
	dd bs=1 count=64 if=/dev/urandom of=$SYSTEM_ROOT/boot/volume.key

	# Add the newly created key to the LUKS partition. This allows the partition to be
	# unlocked with either the password or the key file.
	echo $LUKS_PARTITION_PASSWORD |
		chroot $SYSTEM_ROOT cryptsetup -q luksAddKey $LUKS_PARTITION /boot/volume.key

	# Restrict permissions for the key file and /boot directory to protect them
	# from unauthorized access.
	chroot $SYSTEM_ROOT chmod 000 /boot/volume.key
	chroot $SYSTEM_ROOT chmod -R g-rwx,o-rwx /boot

	# Update the /etc/crypttab file. This file is used by the system to know which
	# partitions need to be decrypted at boot. The format of the line is: <name>
	# <device> <password> <options>.
	echo "$VOLUME_NAME $LUKS_PARTITION /boot/volume.key luks" >>$SYSTEM_ROOT/etc/crypttab

	# Update the Dracut configuration to include the key file and crypttab in the
	# initramfs image.
	echo -e 'install_items+=" /boot/volume.key /etc/crypttab "' \
		>$SYSTEM_ROOT/etc/dracut.conf.d/10-crypt.conf
}

# Performs various system configurations including installing GRUB and applying
# User Configuration settings.
configure_system() {
	# Ensure that the root directory (/) has correct ownership and permissions
	chroot $SYSTEM_ROOT chown root:root /
	chroot $SYSTEM_ROOT chmod 755 /

	# Set the hostname
	echo $HOSTNAME >$SYSTEM_ROOT/etc/hostname

	# Set the language/locale
	echo "LANG=$LANGUAGE" >$SYSTEM_ROOT/etc/locale.conf

	# Check if the timezone file exists
	if [ -f /usr/share/zoneinfo/$TIMEZONE ]; then
		# Set timezone
		ln -sf /usr/share/zoneinfo/$TIMEZONE $SYSTEM_ROOT/etc/localtime
	else
		echo "Error: The timezone file for $TIMEZONE does not exist!"
	fi

	# Copy the DNS resolver configuration from the live system to the new system
	cp /etc/resolv.conf $SYSTEM_ROOT/etc

	# If the chosen C library is glibc, then we need to configure the locales
	if [[ $LIBC == 'glibc' ]]; then
		echo "$LOCALE" >>$SYSTEM_ROOT/etc/default/libc-locales
		xbps-reconfigure -fr $SYSTEM_ROOT/ glibc-locales
	fi

	# If FSTRIM is enabled, add the 'allow-discards' option to the kernel parameters
	if [[ $ENABLE_FSTRIM == 'true' ]]; then
		KERNEL_ARGS+=("rd.luks.allow-discards")
	fi

	# Update the GRUB configuration with the chosen kernel parameters. Note: If
	# there are existing parameters in GRUB_CMDLINE_LINUX_DEFAULT, they will be
	# overwritten.
	sed -i \
		"s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"${KERNEL_ARGS[*]}\"|" \
		$SYSTEM_ROOT/etc/default/grub

	# Install GRUB on the target disk
	chroot $SYSTEM_ROOT grub-install $TARGET_DISK

	# Reconfigure all packages on the new system
	# Note: The '-f' option forces reconfiguration even if the package version hasn't changed
	#       The '-a' option applies to all installed packages, not just the ones specified on the command line
	xbps-reconfigure -far $SYSTEM_ROOT/

	# Finally, update the xbps package manager itself
	# Note: The '-S' option synchronizes the repository index
	#       The '-u' option upgrades all out-of-date packages
	#       The '-y' option assumes 'yes' to all prompts
	xbps-install -SuyR $VOID_REPO -r $SYSTEM_ROOT xbps
}

# Installs CPU microcode based on the user-specified vendor.
install_cpu_microcode() {
	# Determine the appropriate CPU microcode package.
	case "$CPU_VENDOR" in
	"intel")
		# Enable the nonfree repository to install the 'intel-code' package
		xbps-install -SuyR $VOID_REPO -r $SYSTEM_ROOT void-repo-nonfree

		# TODO $VOID_REPO
		xbps-install -Suy -r $SYSTEM_ROOT "intel-ucode"
		;;
	"amd")
		xbps-install -Suy -r $SYSTEM_ROOT "linux-firmware-amd"
		;;
	esac
}

# Sets up a new user in the chroot environment, sets the passwords for the root
# user and the primary user, and grants sudo access to members of the wheel
# group.
create_user() {
	# Adds a new user inside the chroot environment.
	chroot $SYSTEM_ROOT useradd $USERNAME

	# Adds the new user to additional groups.
	chroot $SYSTEM_ROOT usermod -aG $USER_GROUPS $USERNAME

	# Set the password for the 'root' user.
	echo -e "$ROOT_USER_PASSWORD\n$ROOT_USER_PASSWORD" |
		chroot $SYSTEM_ROOT passwd -q root

	# Set the password for the primary user.
	echo -e "$USER_PASSWORD\n$USER_PASSWORD" |
		chroot $SYSTEM_ROOT passwd -q $USERNAME

	# Create a new sudoers file with the appropriate permissions for the wheel
	# group, allowing all members to use sudo.
	echo "%wheel ALL=(ALL) ALL" | chroot $SYSTEM_ROOT tee /etc/sudoers.d/wheel
	chroot $SYSTEM_ROOT chmod 0440 /etc/sudoers.d/wheel
}

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────── Main Script Logic ──────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

check_user_config
select_disk
set_passwords
create_partitions
setup_encryption
setup_lvm
format_and_mount_filesystems
install_base_system
install_user_packages
generate_fstab
configure_grub_for_luks
setup_double_password_entry_avoidance
configure_system
install_cpu_microcode
create_user
