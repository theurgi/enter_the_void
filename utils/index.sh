#!/bin/bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "$DIR/check_config.sh"
source "$DIR/cleanup_and_reboot.sh"
source "$DIR/colors.sh"
source "$DIR/file_utils.sh"
source "$DIR/services.sh"
source "$DIR/xbps.sh"
