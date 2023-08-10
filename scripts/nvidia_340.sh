#!/bin/bash

# This script depends on the following User Configured Global Variables defined
# in env.sh:
#
# - SYSTEM_ROOT
#
# More legacy drivers at: https://www.nvidia.com/en-us/drivers/unix/

if [[ "$LIBC" != "glibc" ]]; then
	echo "Error: The NVIDIA drivers are not compatible with $LIBC. Only glibc is supported."
	exit 1
fi

# Verify user config
check_in_list SYSTEM_ROOT "/mnt"

# Install dependencies
declare -a depends=("libglvnd" "libvdpau" "libglapi")
xbps-install -Sy -r $SYSTEM_ROOT "${depends[@]}"

# Set the URL of the NVIDIA driver
NVIDIA_DRIVER_URL="https://us.download.nvidia.com/XFree86/Linux-x86_64/340.108/NVIDIA-Linux-x86_64-340.108.run"
NVIDIA_DRIVER_PATH="$SYSTEM_ROOT/tmp/NVIDIA-Linux-x86_64-340.108.run"

# Download the NVIDIA driver to the system root's /tmp directory
curl -o $NVIDIA_DRIVER_PATH $NVIDIA_DRIVER_URL

# Make the downloaded file executable
chmod +x $NVIDIA_DRIVER_PATH

# Change directory into the extracted driver
cd $SYSTEM_ROOT/tmp/NVIDIA-Linux-x86_64-340.108

# Apply the patch
#
# https://github.com/warpme/minimyth2/tree/master/script/nvidia/nvidia-340.108/files
cat <<'EOP' | patch -p1
diff -Naur NVIDIA-Linux-x86_64-340.108-old/kernel/nv-drm.c NVIDIA-Linux-x86_64-340.108-new/kernel/nv-drm.c
--- NVIDIA-Linux-x86_64-340.108-old/kernel/nv-drm.c	2021-11-06 20:08:18.779739237 +0200
+++ NVIDIA-Linux-x86_64-340.108-new/kernel/nv-drm.c	2021-11-06 20:42:13.443288819 +0200
@@ -529,7 +529,9 @@ RM_STATUS NV_API_CALL nv_alloc_os_descri
 #if defined(NV_DRM_GEM_OBJECT_PUT_UNLOCKED_PRESENT)
     drm_gem_object_put_unlocked(&nv_obj->base);
 #else
-#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 9, 0)
+#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 15, 0)
+    drm_gem_object_put(&nv_obj->base);
+#elif LINUX_VERSION_CODE >= KERNEL_VERSION(5, 9, 0)
     drm_gem_object_put_locked(&nv_obj->base);
 #else
     drm_gem_object_unreference_unlocked(&nv_obj->base);
EOP

# Execute the NVIDIA driver installer
chroot $SYSTEM_ROOT tmp/NVIDIA-Linux-x86_64-340.108/nvidia-installer --silent --no-questions

# Remove the installer and extracted folder after completion
rm -r $SYSTEM_ROOT/tmp/NVIDIA-Linux-x86_64-340.108
rm $NVIDIA_DRIVER_PATH

# Write dkms.conf for nvidia340
mkdir -p $SYSTEM_ROOT/usr/src/nvidia340-340.108/
cat <<EOF >$SYSTEM_ROOT/usr/src/nvidia340-340.108/dkms.conf
PACKAGE_NAME="nvidia340"
PACKAGE_VERSION="340.108"
AUTOINSTALL="yes"
MAKE[0]="'make' __MAKEJOBS NV_EXCLUDE_BUILD_MODULES='' KERNEL_UNAME=\${kernelver} modules"
BUILT_MODULE_NAME[0]="nvidia"
DEST_MODULE_LOCATION[0]="/kernel/drivers/video"
BUILT_MODULE_NAME[1]="nvidia-modeset"
DEST_MODULE_LOCATION[1]="/kernel/drivers/video"
BUILT_MODULE_NAME[2]="nvidia-drm"
DEST_MODULE_LOCATION[2]="/kernel/drivers/video"
EOF

# Blacklist nouveau
mkdir -p $SYSTEM_ROOT/usr/lib/modprobe.d
echo "blacklist nouveau" >$SYSTEM_ROOT/usr/lib/modprobe.d/nvidia.conf
chmod 644 $SYSTEM_ROOT/usr/lib/modprobe.d/nvidia.conf

echo "NVIDIA driver installed."
