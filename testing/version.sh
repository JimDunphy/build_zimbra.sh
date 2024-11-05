#!/bin/bash


function extract_version_pattern() {
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
test_extract_version_pattern "9.0" "9.0" 0
test_extract_version_pattern "9.0.0" "9.0" 0
test_extract_version_pattern "9.0.0.p38" "9.0" 1
test_extract_version_pattern "8.8.15" "8.8.15" 0
test_extract_version_pattern "8.8.15.p31" "8.8.15" 1
test_extract_version_pattern "11.0.3" "11.0" 1
test_extract_version_pattern "12.1" "12.1" 0
