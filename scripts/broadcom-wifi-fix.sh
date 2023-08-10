#!/bin/bash
#
# This script depends on the following User Configured Global Variables defined
# in env.sh:
#
# - SYSTEM_ROOT

check_in_list "SYSTEM_ROOT" "/mnt"

cp ../configs/wifi_fix/broadcom_wifi_fix.sh \
	$SYSTEM_ROOT/usr/local/bin/broadcom_wifi_fix.sh

chown root:root $SYSTEM_ROOT/usr/local/bin/broadcom_wifi_fix.sh
chmod 755 $SYSTEM_ROOT/usr/local/bin/broadcom_wifi_fix.sh

cp ../configs/wifi_fix/broadcom_wifi_fix.desktop \
	$SYSTEM_ROOT/etc/xdg/autostart/broadcom_wifi_fix.desktop

chown root:root $SYSTEM_ROOT/etc/xdg/autostart/broadcom_wifi_fix.desktop
chmod 644 $SYSTEM_ROOT/etc/xdg/autostart/broadcom_wifi_fix.desktop

write_to_file "ALL ALL=NOPASSWD: /usr/local/bin/broadcom_wifi_fix.sh" \
	$SYSTEM_ROOT/etc/sudoers
