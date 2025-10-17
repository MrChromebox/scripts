#!/bin/bash
#
# Helper functions for the device database
#

# shellcheck disable=SC2155

# Function to get device info from database
get_db_info() {
	local hwid="$1"
	local entry=""

	# Try exact match first
	if [[ -n "${DEVICE_DB["$hwid"]:-}" ]]; then
		entry="${DEVICE_DB["$hwid"]}"
	else
		# Try pattern matching - find the longest (most specific) match
		local best_match=""
		local best_pattern=""
		for pattern in "${!DEVICE_DB[@]}"; do
			if [[ "$hwid" == $pattern ]]; then
				# If this pattern is longer than our current best, use it
				if [[ ${#pattern} -gt ${#best_pattern} ]]; then
					best_pattern="$pattern"
					best_match="${DEVICE_DB["$pattern"]}"
				fi
			fi
		done
		entry="$best_match"
	fi

	echo "$entry"
}

# Function to get device description
get_device_description() {
	local hwid="$1"
	local entry=$(get_db_info "$hwid")
	echo "$entry" | cut -d'|' -f1
}

# Function to get device override
get_device_override() {
	local hwid="$1"
	local entry=$(get_db_info "$hwid")
	echo "$entry" | cut -d'|' -f3
}

# Function to get flags
get_flags() {
	local hwid="$1"
	local entry=$(get_db_info "$hwid")
	echo "$entry" | cut -d'|' -f4
}

# Function to check if device has a specific flag
has_flag() {
	local hwid="$1"
	local flag="$2"
	local flags=$(get_flags "$hwid")
	
	if [[ "$flags" == *"$flag"* ]]; then
		return 0
	else
		return 1
	fi
}

# Function to get board name from HWID
get_board_name() {
	local hwid="$1"
	echo "${hwid^^}" | cut -f1 -d '-' | cut -f1 -d ' '
}

# Function to check if device is EOL (based on CPU platform)
is_eol_device() {
	local hwid="$1"
	local cpu_type=$(get_cpu_type "$hwid")
	
	# EOL platforms from functions.sh
	case "$cpu_type" in
		SNB|IVB|HSW|BDW|BYT|BSW|SKL)
			return 0
			;;
		*)
			return 1
			;;
	esac
}

# Function to check if device has UEFI support
has_uefi_support() {
	local hwid="$1"
	
	# If it has noUEFI flag, no UEFI
	if has_flag "$hwid" "noUEFI"; then
		return 1
	fi
	
	# Otherwise, has UEFI
	return 0
}

# Function to check if device has LAN (implied by hasLAN)
has_lan() {
	local hwid="$1"
	has_flag "$hwid" "hasLAN"
}

# Function to get CPU type
get_cpu_type() {
	local hwid="$1"
	local entry=$(get_db_info "$hwid")
	echo "$entry" | cut -d'|' -f2
}

# Function to get CPU type name
get_cpu_type_name() {
	local cpu_type="$1"
	
	case "$cpu_type" in
		SNB) echo "Intel SandyBridge" ;;
		IVB) echo "Intel IvyBridge" ;;
		HSW) echo "Intel Haswell" ;;
		BYT) echo "Intel BayTrail" ;;
		BDW) echo "Intel Broadwell" ;;
		BSW) echo "Intel Braswell" ;;
		SKL) echo "Intel Skylake" ;;
		APL) echo "Intel ApolloLake" ;;
		KBL) echo "Intel KabyLake" ;;
		GLK) echo "Intel GeminiLake" ;;
		WHL) echo "Intel WhiskeyLake" ;;
		CML) echo "Intel CometLake" ;;
		JSL) echo "Intel JasperLake" ;;
		TGL) echo "Intel TigerLake" ;;
		ADL) echo "Intel AlderLake/RaptorLake-U/P" ;;
		ADN) echo "Intel AlderLake-N" ;;
		TWN) echo "Intel Twinlake" ;;
		MTL) echo "Intel Meteorlake" ;;
		STR) echo "AMD StoneyRidge" ;;
		PCO) echo "AMD Picasso" ;;
		CZN) echo "AMD Cezanne" ;;
		MDN) echo "AMD Mendocino" ;;
		*)   echo "(unrecognized)" ;;
	esac
}

# Function to get device info in original format for compatibility
get_device_info_compat() {
	local hwid="$1"
	local description=$(get_device_description "$hwid")
	local cpu_type=$(get_cpu_type "$hwid")
	local device_override=$(get_device_override "$hwid")
	local flags=$(get_flags "$hwid")
	
	# Build compatibility format: boardName|description|CPU|device override|flags|
	local board_name=$(get_board_name "$hwid")
	echo "${board_name}|${description}|${cpu_type}|${device_override}|${flags}|"
}

# Function to replace the large case statement in functions.sh
# This function uses the database instead of the hardcoded case statement
get_device_info() {
	local hwid="$1"
	local device_entry=""
	
	# Clean up HWID (same as original)
	hwid=$(echo "$hwid" | sed -E 's/X86//g' | sed -E 's/ *$//g')
	
	# Try to get device info from database first
	device_entry=$(get_db_info "$hwid")
	
	if [[ -n "$device_entry" ]]; then
		# Use database entry
		local cpu_type=$(get_cpu_type "$hwid")
		local description=$(get_device_description "$hwid")
		local device_override=$(get_device_override "$hwid")
		
		# Set device variable
		if [[ -n "$device_override" ]]; then
			device="$device_override"
		fi
		
		# Set flags based on database
		set_device_flags_from_database "$hwid"
	else
		return 1
	fi
}


# Function to set device flags based on database entry
set_device_flags_from_database() {
	local hwid="$1"
	local device_entry=$(get_db_info "$hwid")
	
	if [[ -z "$device_entry" ]]; then
		return 1
	fi
	
	# Reset all flags
	export isHswBox=false
	export isBdwBox=false
	export isHswBook=false
	export isBdwBook=false
	export isHsw=false
	export isBdw=false
	export isByt=false
	export isBsw=false
	export isSkl=false
	export isApl=false
	export isKbl=false
	export isGlk=false
	export isStr=false
	export isWhl=false
	export isCml=false
	export isCmlBox=false
	export isCmlBook=false
	export isPco=false
	export isCzn=false
	export isMdn=false
	export isJsl=false
	export isTgl=false
	export isAdl=false
	export isAdl_fixed_rwl=false
	export isAdlN=false
	export isMtl=false
	export isUnsupported=false
	export hasUEFIoption=true
	export hasLAN=false
	export hasCR50=false
	export kbl_rwl18=false
	export isEOL=false
	
	# Get CPU type and set appropriate flags
	local cpu_type=$(get_cpu_type "$hwid")
	local board_name=$(get_board_name "$hwid")

	case "$cpu_type" in
		SNB|IVB)
			isEOL=true
			hasUEFIoption=true
			;;
		HSW)
			has_flag "$hwid" "isCbox" && isHswBox=true || isHswBook=true
			isHsw=true
			isEOL=true
			hasUEFIoption=true
			;;
		BDW)
			has_flag "$hwid" "isCbox" && isBdwBox=true || isBdwBook=true
			isBdw=true
			isEOL=true
			hasUEFIoption=true
			;;
		BYT)
			isByt=true
			isEOL=true
			hasUEFIoption=true
			;;
		BSW)
			isBsw=true
			isEOL=true
			hasUEFIoption=true
			;;
		SKL)
			isSkl=true
			isEOL=true
			hasUEFIoption=true
			;;
		APL)
			isApl=true
			hasUEFIoption=true
			hasCR50=true
			;;
		KBL)
			isKbl=true
			hasUEFIoption=true
			hasCR50=true
			has_flag "$hwid" "kbl_rwl18" && kbl_rwl18=true
			;;
		GLK)
			isGlk=true
			hasUEFIoption=true
			hasCR50=true
			;;
		STR)
			isStr=true
			hasUEFIoption=true
			hasCR50=true
			;;
		WHL)
			isWhl=true
			hasUEFIoption=true
			hasCR50=true
			;;
		CML)
			isCml=true
			hasUEFIoption=true
			hasCR50=true
			has_flag "$hwid" "isCbox" && isCmlBox=true || isCmlBook=true
			;;
		PCO)
			isPco=true
			hasUEFIoption=true
			hasCR50=true
			;;
		CZN)
			isCzn=true
			hasUEFIoption=true
			hasCR50=true
			;;
		MDN)
			isMdn=true
			hasUEFIoption=true
			hasCR50=true
			;;
		JSL)
			isJsl=true
			hasUEFIoption=true
			hasCR50=true
			;;
		TGL)
			isTgl=true
			hasUEFIoption=true
			hasCR50=true
			;;
		ADL)
			isAdl=true
			hasUEFIoption=true
			hasCR50=true
			has_flag "$hwid" "adl_fixed_rwl" && isAdl_fixed_rwl=true
			;;
		ADN)
			isAdlN=true
			hasUEFIoption=true
			hasCR50=true
			;;
		MTL)
			isMtl=true
			hasUEFIoption=true
			hasCR50=true
			;;
		*)
			isUnsupported=true
			hasUEFIoption=false
			;;
	esac

	has_flag "$hwid" "noUEFI" && hasUEFIoption=false
	
	has_lan "$hwid" && hasLAN=true

	return 0
}


# Export functions for use in other scripts
export -f get_device_info
export -f get_device_description
export -f get_device_override
export -f get_cpu_type
export -f get_cpu_type_name
