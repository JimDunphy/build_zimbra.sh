#!/bin/bash

# Function to extract version pattern and determine if a specific version was provided
extract_version_pattern() {
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

