#!/bin/bash

# Checks if given variables are strictly either 'true' or 'false'.
#
# Example:
#   MY_FLAG="true"
#   ANOTHER_FLAG="maybe"
#
#   check_boolean MY_FLAG ANOTHER_FLAG
check_boolean() {
	for var in "$@"; do
		if [[ "${!var}" != "true" && "${!var}" != "false" ]]; then
			echo -e "${RED}ERROR: $var must be either 'true' or 'false'. Got: ${!var}${NC}"
			exit 1
		fi
	done
}

# Checks if given variables are set and non-empty.
#
# Example:
#   REQUIRED_VAR=""
#   ANOTHER_REQUIRED_VAR="hello"
#
#   check_non_empty REQUIRED_VAR ANOTHER_REQUIRED_VAR
check_non_empty() {
	local missing=false

	for var in "$@"; do
		if [ -z "${!var}" ]; then
			echo "${RED}ERROR: Required variable $var is not set.${NC}"
			missing=true
		fi
	done

	if [ "$missing" = true ]; then
		echo "Please ensure all required variables are set in env.sh"
		exit 1
	fi
}

# Checks if a variable's value exists in a given list.
#
# Example:
#   MY_VALUE="apple"
#
#   check_in_list MY_VALUE "apple" "banana" "orange"
check_in_list() {
	local var_name=$1
	local value=${!var_name}
	shift
	local valid_values=("$@")

	if [[ ! " ${valid_values[@]} " =~ " ${value} " ]]; then
		echo -e \
			"${RED}ERROR: $var_name must be one of [${valid_values[*]}]. Got: ${value}${NC}"
		exit 1
	fi
}
