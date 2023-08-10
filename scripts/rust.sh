#!/bin/bash
#
# This script depends on the following User Configured Global Variables defined
# in env.sh:
#
# - SYSTEM_ROOT
# - USERNAME

check_non_empty SYSTEM_ROOT USERNAME

# Install Rust for the user via rustup as recommended by the Rust docs.
#
# https://www.rust-lang.org/tools/install
chroot $SYSTEM_ROOT su - $USERNAME -c \
	'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'

echo "Rust installed for user $USERNAME"
