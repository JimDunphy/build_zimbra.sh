#!/bin/bash

#Globals
specificVersion=0
version_output=""

function extract_version_pattern() {
    local version=$1

    # globals
    #   major, minor, rev, extra, specificVersion

    # Split the input version by dots
    IFS='.' read -ra version_array <<< "$version"
    major="${version_array[0]}"
    minor="${version_array[1]}"
    rev="${version_array[2]}"
    extra="${version_array[3]}"

    # Determine the version pattern based on the segments
    if [ -n "${major}" ] && [ -n "${minor}" ]; then
        if [ -n "${rev}" ]; then
            if [ -n "${extra}" ]; then
                # Handle specific versions like 9.0.0.P46
                specificVersion=1
                version_pattern="${major}.${minor}.${rev}"
            elif [ "${rev}" -eq 0 ]; then
                # Handle general versions like 9.0.0 -> version_pattern=9.0
                specificVersion=0
                version_pattern="${major}.${minor}"
            else
                # Handle other general versions like 10.0.10 -> version_pattern=10.0
                specificVersion=0
                version_pattern="${major}.${minor}"
            fi
        else
            # Handle general versions with only major.minor
            specificVersion=0
            version_pattern="${major}.${minor}"
        fi
    else
        echo "Invalid version pattern"
    fi

version_output=$version_pattern
}


# Function to extract version pattern and determine if a specific version was provided
extract_version_pattern_1() {
    local version=$1
    local specific_version_flag=0

    # Split the input version by dots
    IFS='.' read -ra version_array <<< "$version"
    major="${version_array[0]}"
    minor="${version_array[1]}"
    rev="${version_array[2]}"

    # Determine the version pattern based on the segments
    if [ -n "${major}" ] && [ -n "${minor}" ] && [ -n "${rev}" ]; then
        specific_version_flag=1
        if [ "${major}" -eq 8 ]; then
            # Handle version patterns like 8.8.15
            echo "${major}.${minor}.${rev}"
        else
            # Handle version patterns like 9.0.0 and 10.0.1
            echo "${major}.${minor}"
        fi
    elif [ -n "${major}" ] && [ -n "${minor}" ]; then
        # Handle version patterns like 10.1
        specific_version_flag=0
        echo "${major}.${minor}"
    else
        echo "Invalid version pattern"
    fi

    return $specific_version_flag
}

# Example usage with expected output
echo "Testing with '9.0.0.p38'"
version_output=$(extract_version_pattern "9.0.0.p38")
flag=$?
echo "Extracted version pattern: $version_output  # Expected: 9.0"
echo "Specific version: $flag                     # Expected: 1"
echo

# Example usage with expected output
echo "Testing with '9.0.0.p16'"
version_output=$(extract_version_pattern "9.0.0.p16")
flag=$?
echo "Extracted version pattern: $version_output  # Expected: 9.0"
echo "Specific version: $flag                     # Expected: 1"
echo

echo "Testing with '10.0.2'"
version_output=$(extract_version_pattern "10.0.2")
flag=$?
echo "Extracted version pattern: $version_output  # Expected: 10.0"
echo "Specific version: $flag                     # Expected: 1"
echo

echo "Testing with '8.8.15.p46'"
version_output=$(extract_version_pattern "8.8.15.p46")
flag=$?
echo "Extracted version pattern: $version_output  # Expected: 8.8.15"
echo "Specific version: $flag                     # Expected: 1"
echo

echo "Testing with '10.1'"
version_output=$(extract_version_pattern "10.1")
flag=$?
echo "Extracted version pattern: $version_output  # Expected: 10.1"
echo "Specific version: $flag                     # Expected: 0"
echo

echo "Testing with '10.1.5'"
version_output=$(extract_version_pattern "10.1.5")
flag=$?
echo "Extracted version pattern: $version_output  # Expected: 10.1"
echo "Specific version: $flag                     # Expected: 1"
echo

