#!/bin/bash

find_latest_tag() {
    local repo_url=$1
    local pattern=$2
    local specific_tag=$3
    local latest_tag

    if [[ -z "$specific_tag" ]]; then
        latest_tag=$(git ls-remote --tags "$repo_url" | awk '{print $2}' | grep "$pattern" | grep -v '\^{}' | sort -V | tail -1)
    else
        latest_tag=$(git ls-remote --tags "$repo_url" | awk '{print $2}' | grep "$pattern" | grep -v '\^{}' | sort -V | awk -v specific_tag="$specific_tag" '
            {
                tag = $1
                gsub("refs/tags/", "", tag)
                if (tag <= specific_tag) {
                    latest = tag
                }
            }
            END { print latest }
        ')
    fi

    echo "$latest_tag"
}

latest_tag=$(find_latest_tag "https://github.com/Zimbra/zm-build" "10.0" "10.0.1")
echo "tag matching pattern '10.0' to build tag '10.0.3' is zm-build tag: $latest_tag"

latest_tag=$(find_latest_tag "https://github.com/Zimbra/zm-build" "10.0" "10.0.3")
echo "tag matching pattern '10.0' to build tag '10.0.3' is zm-build tag: $latest_tag"

latest_tag=$(find_latest_tag "https://github.com/Zimbra/zm-build" "10.0" "10.0.8")
echo "tag matching pattern '10.0' to build tag '10.0.8' is zm-build tag: $latest_tag"

latest_tag=$(find_latest_tag "https://github.com/Zimbra/zm-build" "10.0" "10.0.5")
echo "tag matching pattern '10.0' to build tag '10.0.5' is zm-build tag: $latest_tag"

latest_tag=$(find_latest_tag "https://github.com/Zimbra/zm-build" "9.0" "9.0.0.p20")
echo "tag matching pattern '9.0' to build tag '9.0.0.p20' is zm-build tag: $latest_tag"

latest_tag=$(find_latest_tag "https://github.com/Zimbra/zm-build" "9.0" "9.0.0.p40")
echo "tag matching pattern '9.0' to build tag '9.0.0.p40' is zm-build tag: $latest_tag"

latest_tag=$(find_latest_tag "https://github.com/Zimbra/zm-build" "9.0" "9.0.0.p16")
echo "tag matching pattern '9.0' to build tag '9.0.0.p16' is zm-build tag: $latest_tag"

latest_tag=$(find_latest_tag "https://github.com/Zimbra/zm-build" "8.8.15" "8.8.15.p29")
echo "tag matching pattern '8.8.15' to build tag '8.8.15.p29' is zm-build tag: $latest_tag"

latest_tag=$(find_latest_tag "https://github.com/Zimbra/zm-build" "8.8.15" "8.8.15.p46")
echo "tag matching pattern '8.8.15' to build tag '8.8.15.p46' is zm-build tag: $latest_tag"

