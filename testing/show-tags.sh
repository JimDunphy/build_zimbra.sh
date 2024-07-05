#!/bin/bash

# Function to fetch and sort version tags from a remote repository accurately
fetch_ordered_tags() {
    local repository_url=$1    # URL of the git repository
    local tag_pattern=$2       # Version pattern to filter tags, e.g., '9.0'

    # Fetch and format the tags
    tag_list=$(git ls-remote --sort=version:refname --tags "$repository_url" | \
        grep "refs/tags/$tag_pattern" | \
        grep -v '\^{}' | \
        awk '{print $2}' | \
        sed 's#refs/tags/##g' | \
        tr '\n' ',' | \
        sed 's/,$//')

    echo "$tag_list"
}

# Custom Perl script to sort version tags
custom_sort_versions() {
    perl -e '
        sub version_cmp {
            my ($a, $b) = @_;
            my @a_parts = split /(\d+|\D+)/, $a;
            my @b_parts = split /(\d+|\D+)/, $b;
            for (my $i = 0; $i < @a_parts && $i < @b_parts; $i++) {
                if ($a_parts[$i] =~ /^\d+$/ && $b_parts[$i] =~ /^\d+$/) {
                    return $b_parts[$i] <=> $a_parts[$i] if $a_parts[$i] != $b_parts[$i];
                } else {
                    return lc($b_parts[$i]) cmp lc($a_parts[$i]) if lc($a_parts[$i]) ne lc($b_parts[$i]);
                }
            }
            return @b_parts <=> @a_parts;
        }

        my @versions = @ARGV;
        @versions = sort { version_cmp($a, $b) } @versions;
        print join(",", @versions);
    ' "$@"
}

#
#
# Note: 
#   % perl zm-build-print-repos.pl > jim.repo-list
#

# Main function to iterate through a list of repositories and fetch ordered tags
main() {
    local repo_list_file="jim.repo-list"  # File containing list of repositories
    #local version_pattern="10.0"           # Version pattern to filter tags
    local version_pattern="9.0"           # Version pattern to filter tags
    #local version_pattern="8.8.15"           # Version pattern to filter tags
    #local version_pattern="10.1"           # Version pattern to filter tags
    local all_tags=()                     # Array to hold all tags
    local unique_tags=()                  # Array to hold unique tags

    # Check if the repository list file exists
    if [[ ! -f $repo_list_file ]]; then
        echo "Repository list file '$repo_list_file' not found!"
        exit 1
    fi

    # Iterate through each repository in the list
    while IFS= read -r repo_url; do
        ordered_tags=$(fetch_ordered_tags "$repo_url" "$version_pattern")
        
        if [[ -n $ordered_tags ]]; then
            IFS=',' read -r -a tags_array <<< "$ordered_tags"
            for tag in "${tags_array[@]}"; do
                if [[ ! " ${unique_tags[*]} " =~ " ${tag} " ]]; then
                    unique_tags+=("$tag")
                fi
            done
        fi
    done < "$repo_list_file"

    # Sort unique tags using custom sort function
    sorted_unique_tags=$(custom_sort_versions "${unique_tags[@]}")
    combined_tags=$(IFS=, ; echo "${sorted_unique_tags[*]}")

    #echo "Combined unique tags from all repositories (sorted): $combined_tags"
    echo "$combined_tags"
}

# Run the main function
main

