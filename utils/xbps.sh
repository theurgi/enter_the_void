# Function to check if a package exists in the repository
package_exists() {
	xbps-query -R $1 >/dev/null 2>&1
}

get_diff_base_packages() {
	local base_system_packages=($(xbps-query -Rx base-system |
		awk '{print $1}' | cut -d '>' -f1))

	local base_minimal_packages=($(xbps-query -Rx base-minimal |
		awk '{print $1}' | cut -d '>' -f1))

	local -a diff_packages=()

	for i in "${base_system_packages[@]}"; do
		# Skip if package is 'linux'.
		#
		# The installation of the Linux package is handled in the
		# `install_base_system` function of `base_install.sh`. This allows the user
		# to specify a Linux version other than the Void default.
		[[ $i == 'linux' ]] && continue

		skip=
		for j in "${base_minimal_packages[@]}"; do
			[[ $i == $j ]] && {
				skip=1
				break
			}
		done
		[[ -n $skip ]] || diff_packages+=("$i")
	done

	echo "${diff_packages[@]}"
}
