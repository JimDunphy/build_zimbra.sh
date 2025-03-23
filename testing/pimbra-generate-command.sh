#!/bin/bash

# Function to generate PIMBRA_COMMAND based on pimbra_tag
generate_pimbra_command() {
    local pimbra_tag="$1"
    local PIMBRA_COMMAND="null"

    # Download the config.build_pimbra file
    wget "https://github.com/maldua-pimbra/maldua-pimbra-config/raw/refs/tags/${pimbra_tag}/config.build" -O config.build_pimbra > /dev/null 2>&1

    # Check if wget succeeded
    if [ $? -eq 0 ]; then
        # Extract all GIT_OVERRIDES from the config.build_pimbra file
        GIT_OVERRIDES=$(awk '
            /^# Pimbra patches - BEGIN/,/^# Pimbra patches - END/ {
                if ($1 == "%GIT_OVERRIDES") {
                    sub(/^%GIT_OVERRIDES[ \t]*=[ \t]*/, "");
                    print
                }
            }
        ' config.build_pimbra)

        # Initialize an array to store valid --git-overrides
        valid_overrides=()

        # Parse each GIT_OVERRIDES line
        while IFS= read -r line; do
            # Extract the repository and tag
            if [[ "$line" =~ ^([^=]+)=([^ ]+) ]]; then
                repo="${BASH_REMATCH[1]}"
                value="${BASH_REMATCH[2]}"

                # Check if this is a tag line (e.g., zm-web-client.tag=9.0.0.p44-maldua)
                if [[ "$repo" == *".tag" ]]; then
                    # Extract the base repository name (e.g., zm-web-client from zm-web-client.tag)
                    base_repo="${repo%.tag}"

                    # Check if the tag matches the pimbra_tag
                    if [[ "$value" == "${pimbra_tag}-maldua" ]]; then
                        # Find the corresponding remote for this repository
                        remote_line=$(echo "$GIT_OVERRIDES" | grep "^${base_repo}.remote=")
                        if [[ -n "$remote_line" ]]; then
                            # Add both remote and tag to valid_overrides
                            valid_overrides+=("$remote_line")
                            valid_overrides+=("$line")
                        fi
                    fi
                fi
            fi
        done <<< "$GIT_OVERRIDES"

        # If valid_overrides is not empty, construct PIMBRA_COMMAND
        if [ ${#valid_overrides[@]} -gt 0 ]; then
            # Add the special maldua-pimbra.url-prefix first (if it exists)
            url_prefix_line=$(echo "$GIT_OVERRIDES" | grep "^maldua-pimbra.url-prefix=")
            if [[ -n "$url_prefix_line" ]]; then
                valid_overrides=("$url_prefix_line" "${valid_overrides[@]}")
            fi

            # Construct PIMBRA_COMMAND
            PIMBRA_COMMAND=$(printf -- "--git-overrides \"%s\" " "${valid_overrides[@]}")
        else
            echo "Error: No valid repositories found for pimbra_tag [$pimbra_tag]." >&2
        fi
    else
        echo "Error: Failed to download config.build_pimbra for tag [$pimbra_tag]." >&2
    fi

    # Return the PIMBRA_COMMAND
    echo "$PIMBRA_COMMAND"
}

# Test cases
pimbra_tags=("9.0.0.p44" "10.1.5" "10.0.13" "10.1.6" "10.1.4" "8.8.15.p46")

# Iterate through each pimbra_tag
for pimbra_tag in "${pimbra_tags[@]}"; do
    echo "Testing pimbra_tag: [$pimbra_tag]"
    PIMBRA_COMMAND=$(generate_pimbra_command "$pimbra_tag")
    echo "PIMBRA_COMMAND: [$PIMBRA_COMMAND]"
    echo "----------------------------------------"
done

# Clean up downloaded files
rm -f config.build_pimbra
