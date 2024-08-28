#!/bin/bash

run_test() {
    local version=$1
    local expected_output=$2

    echo "Running test for version: $version"

    # Run the script and capture its output
    output=$(./build_zimbra.sh --dry-run --version "$version")

    # Compare the output with the expected output
    if [ "$output" == "$expected_output" ]; then
        echo "Test for version $version passed."
    else
        echo "Test for version $version failed."
        echo "Expected:"
        echo "$expected_output"
        echo "Got:"
        echo "$output"
        exit 1
    fi
}

# Test case for version 10.1
expected_output_10_1=$(cat <<'EOF'
Removing zm-build directory...
Release 10.1.1
Build Tag 100101
CopyTag 10.1.1
Clone Tag 100101
#!/bin/sh
git clone --depth 1 --branch "10.1.1" "git@github.com:Zimbra/zm-build.git"
cd zm-build
ENV_CACHE_CLEAR_FLAG=true ./build.pl --ant-options -DskipTests=true --git-default-tag="10.1.1,10.1.0" --build-release-no="10.1.1" --build-type=FOSS --build-release="DAFFODIL_T100101C100101FOSS" --build-thirdparty-server=files.zimbra.com --no-interactive --build-release-candidate=GA
EOF
)

# Test case for version 10.0
expected_output_10_0=$(cat <<'EOF'
Removing zm-build directory...
Release 10.0.9
Build Tag 100009
CopyTag 10.0.9
Clone Tag 100009
#!/bin/sh
git clone --depth 1 --branch "10.0.9" "git@github.com:Zimbra/zm-build.git"
cd zm-build
ENV_CACHE_CLEAR_FLAG=true ./build.pl --ant-options -DskipTests=true --git-default-tag="10.0.9,10.0.8,10.0.7,10.0.6,10.0.5,10.0.4,10.0.2,10.0.1,10.0.0-GA,10.0.0" --build-release-no="10.0.9" --build-type=FOSS --build-release="DAFFODIL_T100009C100009FOSS" --build-thirdparty-server=files.zimbra.com --no-interactive --build-release-candidate=GA
EOF
)

# Test case for version 9.0
expected_output_9_0=$(cat <<'EOF'
Removing zm-build directory...
Release 9.0.0.p41
Build Tag 090000p41
CopyTag 9.0.0.p38
Clone Tag 090000p38
#!/bin/sh
git clone --depth 1 --branch "9.0.0.p38" "git@github.com:Zimbra/zm-build.git"
cd zm-build
ENV_CACHE_CLEAR_FLAG=true ./build.pl --ant-options -DskipTests=true --git-default-tag="9.0.0.p41,9.0.0.p40,9.0.0.p39,9.0.0.p38,9.0.0.p37,9.0.0.p36,9.0.0.p34,9.0.0.p33,9.0.0.P33,9.0.0.p32.1,9.0.0.p32,9.0.0.p30,9.0.0.p29,9.0.0.p28,9.0.0.p27,9.0.0.p26,9.0.0.p25,9.0.0.p24.1,9.0.0.p24,9.0.0.p23,9.0.0.p22,9.0.0.p21,9.0.0.p20,9.0.0.p19,9.0.0.p18,9.0.0.p17,9.0.0.p16,9.0.0.p15,9.0.0.p14,9.0.0.p13,9.0.0.p12,9.0.0.p11,9.0.0.p10,9.0.0.p9,9.0.0.p8,9.0.0.p7,9.0.0.p6,9.0.0.p5,9.0.0.p4,9.0.0.p3,9.0.0.p2,9.0.0.p1,9.0.0" --build-release-no="9.0.0" --build-type=FOSS --build-release="KEPLER_T090000p41C090000p38FOSS" --build-thirdparty-server=files.zimbra.com --no-interactive --build-release-candidate=GA
EOF
)

# Test case for version 8.8.15
expected_output_8_8_15=$(cat <<'EOF'
Removing zm-build directory...
Release 8.8.15.p46
Build Tag 080815p46
CopyTag 8.8.15.p45
Clone Tag 080815p45
#!/bin/sh
git clone --depth 1 --branch "8.8.15.p45" "git@github.com:Zimbra/zm-build.git"
cd zm-build
ENV_CACHE_CLEAR_FLAG=true ./build.pl --ant-options -DskipTests=true --git-default-tag="8.8.15.p46,8.8.15.p45,8.8.15.p44,8.8.15.p43,8.8.15.p41,8.8.15.p40,8.8.15.P40,8.8.15.p39.1,8.8.15.p39,8.8.15.p37,8.8.15.p36,8.8.15.p35,8.8.15.p34,8.8.15.p33,8.8.15.p32,8.8.15.p31.1,8.8.15.p31,8.8.15.p30,8.8.15.p29,8.8.15.p28,8.8.15.p27,8.8.15.p26,8.8.15.p25,8.8.15.p24,8.8.15.p23,8.8.15.p22,8.8.15.p21,8.8.15.p20,8.8.15.p19,8.8.15.p18,8.8.15.p17,8.8.15.p16,8.8.15.p15.nysa,8.8.15.p15,8.8.15.p14,8.8.15.p13,8.8.15.p12,8.8.15.p11,8.8.15.p10,8.8.15.p9,8.8.15.p8,8.8.15.p7,8.8.15.p6.1,8.8.15.p6,8.8.15.p5,8.8.15.p4,8.8.15.p3,8.8.15.p2,8.8.15.p1,8.8.15" --build-release-no="8.8.15" --build-type=FOSS --build-release="JOULE_T080815p46C080815p45FOSS" --build-thirdparty-server=files.zimbra.com --no-interactive --build-release-candidate=GA
EOF
)

run_test "10.1" "$expected_output_10_1"
run_test "10.1.1" "$expected_output_10_1"
run_test "10.0" "$expected_output_10_0"
run_test "10.0.9" "$expected_output_10_0"
run_test "9.0" "$expected_output_9_0"
run_test "9.0.0.p41" "$expected_output_9_0"
run_test "8.8.15" "$expected_output_8_8_15"
run_test "8.8.15.p46" "$expected_output_8_8_15"

#echo "All tests passed successfully."

