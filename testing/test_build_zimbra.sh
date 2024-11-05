#!/bin/bash

#
# Runs some default test cases on version 8.8.15, 9.0, 10.0, and 10.1
#    to find any problems with expected output
# One specific version and the latest version to make
# 
# Note: Script can handle the dynamic output used in building the release-release, build-release-no, git-default-tag, and --branch
#

# Color codes
RED='\033[31m'
GREEN='\033[32m'
NC='\033[0m' # No Color (reset)

# Function to run a test case
run_test() {
    local version="$1"
    local expected_release="$2"
    local expected_branch="$3"
    local expected_git_default_tag="$4"
    local expected_build_release_no="$5"
    
    # Capture the output of the command for the specified version
    command_output=$(./build_zimbra.sh --dry-run --version "$version")
    
    # Determine the build prefix based on the version
    if [[ "$version" == "9.0"* ]]; then
        prefix="KEPLER_T"
    elif [[ "$version" == "8.8.15"* ]]; then
        prefix="JOULE_T"
    else
        prefix="DAFFODIL_T"
    fi
    
    # Extract Build Tag and Clone Tag from the command output
    build_tag=$(echo "$command_output" | grep -oP 'Build Tag \K[0-9a-zA-Z]+')
    clone_tag=$(echo "$command_output" | grep -oP 'Clone Tag \K[0-9a-zA-Z]+')
    
    # Construct the expected --build-release value
    expected_build_release="${prefix}${build_tag}C${clone_tag}FOSS"
    
    # Verify the Release line
    if [[ "$command_output" =~ "Release $expected_release" ]]; then
        echo "Release $expected_release verified for version $version."
    else
        echo -e "${RED}Test failed: Expected Release $expected_release for version $version.${NC}"
        return 1
    fi
    
    # Verify the branch in git clone command
    if [[ "$command_output" =~ "--branch \"$expected_branch\"" ]]; then
        echo "Branch $expected_branch verified for version $version."
    else
        echo -e "${RED}Test failed: Expected branch $expected_branch for version $version.${NC}"
        return 1
    fi

    # Verify --git-default-tag in the build.pl command
    if [[ "$command_output" =~ "--git-default-tag=\"$expected_git_default_tag\"" ]]; then
        echo "--git-default-tag $expected_git_default_tag verified for version $version."
    else
        echo -e "${RED}Test failed: Expected --git-default-tag=$expected_git_default_tag for version $version.${NC}"
        return 1
    fi

    # Verify --build-release-no in the build.pl command
    if [[ "$command_output" =~ "--build-release-no=\"$expected_build_release_no\"" ]]; then
        echo "--build-release-no $expected_build_release_no verified for version $version."
    else
        echo -e "${RED}Test failed: Expected --build-release-no=$expected_build_release_no for version $version.${NC}"
        return 1
    fi
    
    # Verify the dynamically constructed --build-release argument
    if [[ "$command_output" =~ "--build-release=\"$expected_build_release\"" ]]; then
        echo "--build-release $expected_build_release verified for version $version."
    else
        echo -e "${RED}Test failed: Expected --build-release=$expected_build_release for version $version.${NC}"
        return 1
    fi
    
    # Final success message in green
    echo -e "${GREEN}Test passed for version $version.${NC}"
}

# Define test cases with expected values
# Format: run_test "version" "expected_release" "expected_branch" "expected_git_default_tag" "expected_build_release_no"

# Define test cases with expected values
# Format: run_test "version" "expected_release" "expected_branch" "expected_git_default_tag" "expected_build_release_no"

# Latest Release to build
run_test "10.1" "10.1.3" "10.1.1" "10.1.3,10.1.2,10.1.1,10.1.0" "10.1.3"
run_test "10.0" "10.0.11" "10.0.9" "10.0.11,10.0.10,10.0.9,10.0.8,10.0.7,10.0.6,10.0.5,10.0.4,10.0.2,10.0.1,10.0.0-GA,10.0.0" "10.0.11"
run_test "9.0" "9.0.0.p43" "9.0.0.p38" "9.0.0.p43,9.0.0.p42,9.0.0.p41,9.0.0.p40,9.0.0.p39,9.0.0.p38,9.0.0.p37,9.0.0.p36,9.0.0.p34,9.0.0.p33,9.0.0.P33,9.0.0.p32.1,9.0.0.p32,9.0.0.p30,9.0.0.p29,9.0.0.p28,9.0.0.p27,9.0.0.p26,9.0.0.p25,9.0.0.p24.1,9.0.0.p24,9.0.0.p23,9.0.0.p22,9.0.0.p21,9.0.0.p20,9.0.0.p19,9.0.0.p18,9.0.0.p17,9.0.0.p16,9.0.0.p15,9.0.0.p14,9.0.0.p13,9.0.0.p12,9.0.0.p11,9.0.0.p10,9.0.0.p9,9.0.0.p8,9.0.0.p7,9.0.0.p6,9.0.0.p5,9.0.0.p4,9.0.0.p3,9.0.0.p2,9.0.0.p1,9.0.0" "9.0.0"
run_test "8.8.15" "8.8.15.p47" "8.8.15.p45" "8.8.15.p47,8.8.15.p46,8.8.15.p45,8.8.15.p44,8.8.15.p43,8.8.15.p41,8.8.15.p40,8.8.15.P40,8.8.15.p39.1,8.8.15.p39,8.8.15.p37,8.8.15.p36,8.8.15.p35,8.8.15.p34,8.8.15.p33,8.8.15.p32,8.8.15.p31.1,8.8.15.p31,8.8.15.p30,8.8.15.p29,8.8.15.p28,8.8.15.p27,8.8.15.p26,8.8.15.p25,8.8.15.p24,8.8.15.p23,8.8.15.p22,8.8.15.p21,8.8.15.p20,8.8.15.p19,8.8.15.p18,8.8.15.p17,8.8.15.p16,8.8.15.p15.nysa,8.8.15.p15,8.8.15.p14,8.8.15.p13,8.8.15.p12,8.8.15.p11,8.8.15.p10,8.8.15.p9,8.8.15.p8,8.8.15.p7,8.8.15.p6.1,8.8.15.p6,8.8.15.p5,8.8.15.p4,8.8.15.p3,8.8.15.p2,8.8.15.p1,8.8.15" "8.8.15"

# Specific Release to build
run_test "10.1.2" "10.1.2" "10.1.1" "10.1.2,10.1.1,10.1.0" "10.1.2"
run_test "10.0.8" "10.0.8" "10.0.6" "10.0.8,10.0.7,10.0.6,10.0.5,10.0.4,10.0.2,10.0.1,10.0.0-GA,10.0.0" "10.0.8"
run_test "9.0.0.p36" "9.0.0.p36" "9.0.0.p36" "9.0.0.p36,9.0.0.p34,9.0.0.p33,9.0.0.P33,9.0.0.p32.1,9.0.0.p32,9.0.0.p30,9.0.0.p29,9.0.0.p28,9.0.0.p27,9.0.0.p26,9.0.0.p25,9.0.0.p24.1,9.0.0.p24,9.0.0.p23,9.0.0.p22,9.0.0.p21,9.0.0.p20,9.0.0.p19,9.0.0.p18,9.0.0.p17,9.0.0.p16,9.0.0.p15,9.0.0.p14,9.0.0.p13,9.0.0.p12,9.0.0.p11,9.0.0.p10,9.0.0.p9,9.0.0.p8,9.0.0.p7,9.0.0.p6,9.0.0.p5,9.0.0.p4,9.0.0.p3,9.0.0.p2,9.0.0.p1,9.0.0" "9.0.0"
run_test "8.8.15.p40" "8.8.15.p40" "8.8.15.p40" "8.8.15.p40,8.8.15.P40,8.8.15.p39.1,8.8.15.p39,8.8.15.p37,8.8.15.p36,8.8.15.p35,8.8.15.p34,8.8.15.p33,8.8.15.p32,8.8.15.p31.1,8.8.15.p31,8.8.15.p30,8.8.15.p29,8.8.15.p28,8.8.15.p27,8.8.15.p26,8.8.15.p25,8.8.15.p24,8.8.15.p23,8.8.15.p22,8.8.15.p21,8.8.15.p20,8.8.15.p19,8.8.15.p18,8.8.15.p17,8.8.15.p16,8.8.15.p15.nysa,8.8.15.p15,8.8.15.p14,8.8.15.p13,8.8.15.p12,8.8.15.p11,8.8.15.p10,8.8.15.p9,8.8.15.p8,8.8.15.p7,8.8.15.p6.1,8.8.15.p6,8.8.15.p5,8.8.15.p4,8.8.15.p3,8.8.15.p2,8.8.15.p1,8.8.15" "8.8.15"

# Add more test cases as needed

