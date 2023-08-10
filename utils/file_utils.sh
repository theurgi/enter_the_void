#!/bin/bash

# write_to_file
#
# This function takes either an array of lines or a single string line and a
# file path as arguments, and writes them to the file at the specified path. If
# the file does not exist, it will be created. By default, it appends the lines
# to the file, without overwriting the existing content. If the --overwrite flag
# is passed, the function will overwrite the file.
#
# Usage:
#   write_to_file <array|string> <filepath> [--overwrite]
#
# Examples:
#   lines=("Hello," "this is" "a test.")
#   write_to_file lines "/path/to/file"
#
#   write_to_file "This is a single string" "/path/to/file" --overwrite
#
write_to_file() {
	local content="$1"
	local filepath="$2"
	local flag=$3

	# Check if content is an array
	if declare -p "$content" 2>/dev/null | grep -q 'declare \-a'; then
		local -n arr="$content"
		# Determine mode
		if [[ "$flag" == "--overwrite" ]]; then
			printf "%s\n" "${arr[@]}" >"$filepath"
		else
			printf "%s\n" "${arr[@]}" >>"$filepath"
		fi
	else
		# Determine mode
		if [[ "$flag" == "--overwrite" ]]; then
			echo -e "$content" >"$filepath"
		else
			echo -e "$content" >>"$filepath"
		fi
	fi
}
