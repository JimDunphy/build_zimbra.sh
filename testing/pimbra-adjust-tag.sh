adjust_release() {
    local release="$1"
    local adjustment="$2"

    # Check if the release contains a '.p' for patch version
    if [[ "$release" == *".p"* ]]; then
        # Extract the prefix and patch version
        local prefix="${release%.p*}"
        local patch_version="${release##*.p}"

        # Adjust the patch version
        if [[ "$adjustment" == "+1" ]]; then
            patch_version=$((patch_version + 1))
        elif [[ "$adjustment" == "-1" ]]; then
            patch_version=$((patch_version - 1))
        fi

        # Reconstruct the release string
        echo "${prefix}.p${patch_version}"
    else
        # Handle the case where there is no '.p' (e.g., 10.0.13)
        local major_minor_patch="$release"
        local patch_version="${major_minor_patch##*.}"

        # Adjust the patch version
        if [[ "$adjustment" == "+1" ]]; then
            patch_version=$((patch_version + 1))
        elif [[ "$adjustment" == "-1" ]]; then
            patch_version=$((patch_version - 1))
        fi

        # Reconstruct the release string
        echo "${major_minor_patch%.*}.${patch_version}"
    fi
}

# Example usage:
release="9.0.0.p43"
new_release=$(adjust_release "$release" "+1")
echo "$new_release"  # Output: 9.0.0.p44

release="9.0.0.p43"
new_release=$(adjust_release "$release" "-1")
echo "$new_release"  # Output: 9.0.0.p42

release="10.0.13"
new_release=$(adjust_release "$release" "+1")
echo "$new_release"  # Output: 10.0.14

release="10.1.6"
new_release=$(adjust_release "$release" "-1")
echo "$new_release"  # Output: 10.1.5
