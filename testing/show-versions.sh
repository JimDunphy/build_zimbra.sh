#!/bin/bash


declare -a Versions
readarray -t Versions <<< "$( git ls-remote --tags "git@github.com:Zimbra/zm-build.git" | awk '{print $2}' | sed 's|refs/tags/||' | grep -vE '^8.7|beta|U20|RRHEL8|\^\{\}' | grep -E "^[1-9][0-9]*\\.[0-9]+" | cut -d "." -f 1,2 | sort -n -u )"

# Loop through each known version
for version in "${Versions[@]}"; do
	if [ "${version}" == "8.8" ]; then
		version="8.8.15"
	fi
	echo "Building tags for version $version"

done


