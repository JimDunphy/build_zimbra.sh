#!/bin/bash

debug=0
function d_echo() {
    if [ "$debug" -eq 1 ]; then
        echo "$@" >&2
    fi
}



# additional checking - sent by Vince
function extract_version_pattern() {
    local version=$1

    # globals
    #   major,minor,rev,extra,specificVersion

    # Split the input version by dots
    IFS='.' read -ra version_array <<< "$version"
    major="${version_array[0]}"
    minor="${version_array[1]}"
    rev="${version_array[2]}"
    extra="${version_array[3]}"
    dot="${version_array[4]}"
	# Handle patch dot releases = e.g. 9.0.0.p7.1
    if [ -n "${dot}" ]; then
		extra="${extra}.${dot}"
	fi
    # Ensure that major, minor and rev, if present, are numeric
	if [[ $major =~ ^[0-9]+$ ]] && [[ $minor =~ ^[0-9]+$ ]] && [[ $rev =~ ^[0-9]+$ ]]; then
		d_echo "major, minor and rev are all numeric"
	elif [[ $major =~ ^[0-9]+$ ]] && [[ $minor =~ ^[0-9]+$ ]] && [ -z "${rev}" ]; then
		d_echo "major and minor are all numeric, rev not supplied"
	elif [[ $major =~ ^[0-9]+$ ]] && [ -z "${minor}" ] && [ -z "${rev}" ]; then
		d_echo "major is all numeric, minor and rev not supplied"
	else
		echo "Invalid version - non-numeric characters found"
		exit 1
	fi
	
    # Determine the version pattern - 8 and 9 will be 3-part, all others 2-part
    if [ "${major}" == "8" ]; then
        if [ -z "${minor}" ]; then
            minor="8"
            rev="15"
            extra=""
        elif [ "${minor}" == "8" ]; then
            if [ -z "${rev}" ]; then
                rev="15"
                extra=""
			elif [ "${rev}" != "15" ]; then
				echo "Invalid 8.8.n version - only 8.8.15 is supported"
				exit 1
			fi
        else
            echo "Invalid 8.n.n version - only 8.8.15 is supported"
			exit 1
 		fi
		# Handle version 8.8.15 as a general version (not specific check-in 8.8.15)
		if [ -z "${extra}" ]; then
			specificVersion=0
		else
			specificVersion=1
		fi
		version_pattern="${major}.${minor}.${rev}"
    elif [ "${major}" == "9" ]; then
        if [ -z "${minor}" ]; then
            minor="0"
            rev="0"
            extra=""
        elif [ "${minor}" == "0" ]; then
            if [ -z "${rev}" ]; then
                rev="0"
                extra=""
			elif [ "${rev}" != "0" ]; then
				echo "Invalid 9.0.n version - only 9.0.0 is supported"
				exit 1
			fi
		else
            echo "Invalid 9.n.n version - only 9.0.0 is supported"
			exit 1
		fi
		# Handle version 9.0.0 as a general version (not specific check-in 9.0.0)
		if [ -z "${extra}" ]; then
			specificVersion=0
		else
			specificVersion=1
		fi
		version_pattern="${major}.${minor}.${rev}"
    elif [ "${major}" -lt 10 ]; then
		echo "Invalid version - versions below 8.8.15 are not supported"
		exit 1
    elif [ -n "${major}" ] && [ -n "${minor}" ]; then
        if [ -n "${rev}" ]; then
            # Handle version patterns like n.n.n (specific versions)
            specificVersion=1
        else
            # Handle version patterns like n.n (general versions)
            specificVersion=0
        fi
		#V Sherwood - All in one requires version_pattern to be the family - not the specific version even if rev specified
        version_pattern="${major}.${minor}"
    else
        echo "Invalid version - version n.n[.n] required"
		exit 1
    fi
		
    d_echo "extract_version_pattern() - major[$major] minor[$minor] rev[$rev] extra[$extra] version_pattern[$version_pattern] specificVersion[$specificVersion]"
}

function extract_version_pattern_1() {
    local version="$1"
    
    #normalize so that 9.0 behaves like 10.0,10.1,10.2,11.0,...
    if [ $version == "9.0.0" ]; then version="9.0"; fi  

    # Split the version string into components
    IFS='.' read -ra version_array <<< "$version"
    local major="${version_array[0]}"
    local minor="${version_array[1]}"
    local rev="${version_array[2]}"
    local extra="${version_array[3]}"

    # Determine the version pattern and specificVersion status
    if [ -n "$major" ] && [ -n "$minor" ]; then
        if [ -n "$rev" ]; then
            # Specific version if three segments or extra is present
            specificVersion=1
            if [ "${major}" -ge 9 ]; then
                version_pattern="${major}.${minor}"
            else
                version_pattern="${major}.${minor}.${rev}"
            fi
        else
            # General version if only two segments
            specificVersion=0
            version_pattern="${major}.${minor}"
        fi

        # Special handling for 8.8.15 to distinguish specific/general
        if [ "$major" -eq 8 ] && [ "$minor" -eq 8 ] && [ "$rev" -eq 15 ]; then
            specificVersion=$([ -z "$extra" ] && echo 0 || echo 1)
            version_pattern="${major}.${minor}.${rev}"
        fi

    else
        # Invalid version format for cases missing required segments
        echo "Invalid version pattern"
        #exit 1
    fi
}

# Color codes
RED='\033[31m'
GREEN='\033[32m'
NC='\033[0m' # No Color (reset)

# Define the test function
function test_extract_version_pattern() {
    local input_version="$1"
    local expected_pattern="$2"
    local expected_flag="$3"

    echo "Testing with '$input_version'"

    # Call extract_version_pattern and capture output
    version_pattern=""
    specificVersion=""
    extract_version_pattern "$input_version"
    flag=$specificVersion

    # Display results and compare with expected values
    echo "Extracted version pattern: $version_pattern  # Expected: $expected_pattern"
    echo "Specific version: $flag                     # Expected: $expected_flag"
    echo

    # Check if results match expected values
    if [[ "$version_pattern" == "$expected_pattern" && "$flag" -eq "$expected_flag" ]]; then
       echo -e "${GREEN}Test passed.${NC}"
    else
       echo -e "${RED}Test failed.${NC}"
    fi
    echo "-----------------------------"
}

# Test cases
# [version] [expected version pattern] [specific version]
test_extract_version_pattern "10.0.2" "10.0" 1
test_extract_version_pattern "10.1.0" "10.1" 1
test_extract_version_pattern "10.1" "10.1" 0
test_extract_version_pattern "10.0" "10.0" 0
test_extract_version_pattern "9.0" "9.0.0" 0
test_extract_version_pattern "9.0.0" "9.0.0" 0
test_extract_version_pattern "9.0.0.p38" "9.0.0" 1
test_extract_version_pattern "8.8.15" "8.8.15" 0
test_extract_version_pattern "8.8.15.p31" "8.8.15" 1
test_extract_version_pattern "11.0.3" "11.0" 1
test_extract_version_pattern "12.1" "12.1" 0
test_extract_version_pattern "8" "8.8.15" 0
test_extract_version_pattern "8.8.15.p6.1" "8.8.15" 1
test_extract_version_pattern "9.0.0.p7.1" "9.0.0" 1

