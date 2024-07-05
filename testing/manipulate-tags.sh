#!/bin/bash

# Function to filter out tags newer than the specified version and keep that version and older ones
filter_tags_up_to() {
    local tag_list=$1       # Comma-separated list of all tags
    local max_version=$2    # Maximum version to include, e.g., '9.0.0.p38'

    # Add commas to ensure complete matches and prevent substring errors
    local tagscomma="$tag_list,"
    local releasecomma="$max_version,"

    # Find the part of the tag list that starts with the max version and keep everything after it
    local valid_tags=${tagscomma#*,$releasecomma}
    
    # If the max_version is not found, the original list remains unchanged, meaning the max_version is incorrect
    if [[ "$valid_tags" == "$tagscomma" ]]; then
        echo "Error: The specified max version '$max_version' does not exist in the tag list."
        return 1  # Return with error
    fi

    # Remove the trailing comma from the original list and then everything after the max_version
    valid_tags="$releasecomma$valid_tags"
    local earlier_releases=${valid_tags%,$releasecomma*}

    # Remove the trailing comma added earlier
    earlier_releases=${earlier_releases%,}

    echo "$earlier_releases"
}

# Function to fetch the most recent tag based on commit date
# This requires that the repository has already been cloned and you are working from this repository
# cd zm-mailbox for example; 
fetch_latest_tag_by_commit_date() {
    local tag_pattern=$1

    # Fetch the most recent tag matching the pattern based on commit date
    local latest_tag=$(git for-each-ref --sort=creatordate --format '%(refname:short)' refs/tags | grep "$tag_pattern" | tail -1)

    echo "$latest_tag"
}

# Define the function to fetch the highest version tag
fetch_highest_tag() {
    local tag=$1  # Local variable to store the tag passed as an argument

    # Use the variable in the git command
    # Note: Use double quotes for variable expansion and careful escaping of characters
    git ls-remote --tags https://github.com/Zimbra/zm-mailbox.git | \
        grep "refs/tags/${tag//./\\.}" | \
        awk -F'/' '{print $3}' | \
        sed 's/\^{}//g' | \
        sed -E 's/([0-9]+)\.([0-9]+)\.([0-9]+)\.p([0-9]+)(\.[0-9]+)?/\1.\2.\3p\4\5/' | \
        sort -V | \
        tail -1 | \
        sed 's/\([0-9]\+\)\.\([0-9]\+\)\.\([0-9]\+\)p\([0-9]\+\)/\1.\2.\3.p\4/'
}

# Function to fetch and sort version tags from a remote repository accurately
fetch_ordered_tags() {
    local repository_url=$1    # URL of the git repository
    local tag_pattern=$2       # Version pattern to filter tags, e.g., '9.0'

    # Fetch and format the tags
    tag_list=$(git ls-remote --sort=version:refname --tags $repository_url | \
        grep "refs/tags/$tag_pattern" | \
        grep -v '\^{}' | \
        awk '{print $2}' | \
        sed 's#refs/tags/##g' | \
        tac | \
        tr '\n' ',' | \
        sed 's/,$//')

    echo "$tag_list"
}

# Function to fetch tags ordered by commit creation date
#
#    git for-each-ref: Lists all tags, sorted by the date of the commits they point to.
#    grep "${tag_pattern//./\\.}": Filters tags to include only those that contain the specified version pattern. The pattern 
#                                  escaping replaces dots to match literally.
#    tac: Reverses the order so the most recent tag comes first.
#    tr '\n' ',': Transforms the output into a comma-separated list.
#    sed 's/,$//': Removes the trailing comma from the list.
#

# This requires that the repository has already been cloned and you are working from this repository
# cd zm-mailbox for example; 
fetch_ordered_tags_from_clone() {
    local tag_pattern=$1  # The version pattern to filter tags, e.g., '9.0'

    # Fetch and format the tags
    tag_list=$(git for-each-ref --sort=creatordate --format '%(refname:short)' refs/tags | \
        grep "${tag_pattern//./\\.}" | \
        tac | \
        tr '\n' ',' | \
        sed 's/,$//')  # Convert to comma-separated list and remove trailing comma

    echo "$tag_list"
}

# usage: 
#   $0 10.0
#   $0 9.0
#   $0 8.8.15


echo "highest to lowest tag for version $1"
repository_url="https://github.com/Zimbra/zm-mailbox.git"
fetch_ordered_tags $repository_url $1


# Example usage:
echo "Fetching ordered tags for $version_pattern from $repository_url"
tag_list=$(fetch_ordered_tags "$repository_url" "$1")
echo "Ordered tags: $tag_list"

echo "highest tag for version $1"
fetch_highest_tag $1

#=======================================================================
# requires local clone
cd zm-mailbox
echo "fetch_ordered_tags from cloned repository: highest to lowest tag for version $1"
fetch_ordered_tags_from_clone $1

echo "highest tag based on commit_date for version $1"
fetch_latest_tag_by_commit_date $1
#=======================================================================


# usage: 10.0 10.0.6
#        8.8.15 8.8.15.p40
echo "build for these tags only"
filter_tags_up_to $tag_list $2
