#!/bin/bash
#
# Claude 3.5 sonnet assembled and structured this code.
# openai GTP4o created the functions
#
# humans: 6/26/2024: J Dunphy & V Sherwood provided snippets of code 
#
# usage: ./build_tags.sh 10.0.8
#        ./build_tags.sh 10.0.3
#        ./build_tags.sh 9.0.0.p38
#        ./build_tags.sh 8.8.15.p46
#
# Note: Writes to stdout
#
# Given a FOSS version, it will clone zm_build with the tag associated with it. Generate a list of repositories and finally provide the list
#  of tags that should be used to build and compile FOSS Zimbra for that version of FOSS.
#
# The extra logic wrapped around zm_build is so that repositories that have been dropped are not included in the list for newer
#  builds. This may be a extra pedantic check vs simply taking the latest development branch. The actual build process would
#  only be using the repositories required so this is copying that behavior. 
#
# TODO
#   - generate tag file for all
#   - rm zm-build, repo_urls.txt
#   - check existance if zm-build and fail
#   - default to latest version or all versions
#   - add to build_zimbra.sh with wellknown file names (tags_for_10.txt,tags_for_8.txt,tags_for_9.txt)
#   - should there be an option to save to file names vs stdout
#

#

# extra verbose
debug=0
scriptVersion=1.1

#==================================================================================
function d_echo() {
    if [ "$debug" -eq 1 ]; then
        echo "$@"
    fi
}

# Function to extract version components
function extract_version() {
    local full_version=$1
    local version_pattern=${full_version%.*}
    local release_to_build=$full_version

    echo "$version_pattern" "$release_to_build"
}

function generate_repo_urls() {
    local repo_list_file="./zm-build/instructions/FOSS_repo_list.pl"
    local remote_list_file="./zm-build/instructions/FOSS_remote_list.pl"
    local default_remote="gh-zm"
    local output_file="repo_urls.txt"

    perl -e '
        use strict;
        use warnings;
        use Data::Dumper;

        # File paths
        my $repo_list_file = "'"$repo_list_file"'";
        my $remote_list_file = "'"$remote_list_file"'";

        # Load the repo list file
        require $repo_list_file;
        our @ENTRIES;
        my @repo_entries = @ENTRIES;

        # Load the remote list file
        require $remote_list_file;
        our %ENTRIES;
        my %remote_entries = @ENTRIES;

        # Default remote
        my $default_remote = "'"$default_remote"'";

        # Print URLs
        foreach my $entry (@repo_entries) {
            my $name = $entry->{name};
            my $remote = $entry->{remote} // $default_remote;
            if (exists $remote_entries{$remote}->{"url-prefix"}) {
                my $url_prefix = $remote_entries{$remote}->{"url-prefix"};
                print "$url_prefix/$name.git\n";
            } else {
                print STDERR "No valid remote for $name\n";
            }
        }
    ' > "$output_file"

    d_echo "Repository URLs have been saved to $output_file"
}

# Function to find the latest tag
function find_latest_tag() {
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

#==================================================================================
# clone the repository with the desired tag
function clone_repo() {
    local tag=$1
    local repo_url="git@github.com:Zimbra/zm-build.git"
    local clone_dir="zm-build"

    if ! git clone --quiet --depth 1 --branch "$tag" "$repo_url" "$clone_dir" 2>/dev/null; then
        echo "Error: Failed to clone the repository. Exiting." >&2
        exit 1
    fi
}

#==================================================================================
# fetch and sort version tags from a remote repository 
function fetch_ordered_tags() {
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

#==================================================================================
# Custom Perl script to sort version tags because of version 9 and 8.8.15 with nonconformant tags
function custom_sort_versions() {
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

#==================================================================================

# iterate through a list of repositories and fetch ordered tags
function process_repo_tags() {
    local repo_list_file=$1
    local version_pattern=$2
    local all_tags=()
    local unique_tags=()
    local print_once=false

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
                if [[ ! "${tag} " =~ "beta" ]]; then
                   if [[ ! " ${unique_tags[*]} " =~ " ${tag} " ]]; then
                      unique_tags+=("$tag")
                   fi
                else
                    if [[ "$print_once" = false ]]; then
                        d_echo "Omitting beta tag [${tag}]"
                        print_once=true
                    fi
                fi
            done
        fi
    done < "$repo_list_file"

    # Sort unique tags using custom sort function
    sorted_unique_tags=$(custom_sort_versions "${unique_tags[@]}")
    echo "$sorted_unique_tags"
}


#==================================================================================

# Main script
if [ $# -eq 0 ]; then
    d_echo "No version provided. Please provide a version string."
    exit 1
fi

version_input=$1
read -r version_pattern release_to_build <<< $(extract_version "$version_input")

d_echo "Version pattern: $version_pattern"
d_echo "Release to build: $release_to_build"


# Using the find_latest_tag function
desired_tag=$(find_latest_tag "https://github.com/Zimbra/zm-build" "$version_pattern" "$release_to_build")
d_echo "Desired tag: $desired_tag"

# Clone the repository with the desired tag
clone_repo "$desired_tag"

# Get Zimbra FOSS URLs
d_echo "Fetching Zimbra FOSS URLs..."
generate_repo_urls

#%%%
#temp_repo_list=$(mktemp)
#zimbra_foss_urls "$temp_repo_list"

# Process repository tags
d_echo "Processing repository tags..."
#combined_tags=$(process_repo_tags "$temp_repo_list" "$version_pattern")
combined_tags=$(process_repo_tags "repo_urls.txt" "$version_pattern")
#echo "Combined unique tags from all repositories (sorted): $combined_tags"
echo "$combined_tags"

# Clean up
#rm -f "$temp_repo_list"
