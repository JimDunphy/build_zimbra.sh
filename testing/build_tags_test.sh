#!/bin/bash
#
# Written: 6/26/2024: J Dunphy & V Sherwood provided snippets of code
# Assist: GTP4o and Claude 3.5 sonnet
#
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
# %%% Bugs
#   Why do not see 9.0.0.p7.1 in our build.pl tag list.  Hint: search for 9.0.0.p16 which would be 9.0.0.p7.1
#     ie) git ls-remote --tags "https://github.com/Zimbra/zm-build" | awk '{print $2}' | grep 9.0 | grep -v '\^{}
#
#     function: find_latest_tag() will return this extra level and specific tag because we are processing zm-build but 
#        we are not returning this in custom_sort_version() which doesn't have the extra logic for processing a tag that convuluted
#        to match.  
#
#        zimbra_tag_helper/zm-build-filter-tags-9.sh never shows this in its output. We are matching that output
#          given we have a lot of testing with zm-build-filter-tags-9.sh so the output remains the same for this program.
#     
#     One explanation might be that specific tag only exists in zm-build which isn't included in repositories for our build.pl tags?
#     Another explanation might be that there are more of these 4-5 level odd tag releases and our sorting functions are missing it.
#


#==============================================================================================================
# BEGIN DUPS - don't copy to build_zimbra.sh
#
# Dups of functions in build_zimbra.sh
# Do Not Copy this section
#

function strip_newer_tags()
{
  # Trims off the leading tags that are newer than the requested release
 
  # Add [,] to both strings to avoid matching extended release numbers. e.g. 10.0.0-GA when searching for 10.0.0, or 9.0.0.p32.1 when searching for 9.0.0.p32
  tagscomma="$tags,"
  releasecomma="$release,"

  # earlier_releases will either contain the entire tags string if the requested release wasn't found
  # or the tail of the tags string after the requested release (which could be nothing if the earliest release was requested)
  earlier_releases=${tagscomma#*$releasecomma}

  if [ -n "${earlier_releases}" ]; then
    # Some earlier releases in tags - strip the [,] we added for searching
    earlier_releases=${earlier_releases%?}
  fi

  if [ "$tags" == "$earlier_releases" ]; then
    # If earlier_releases contains everything then the requested release does not exist
    echo "Bad release number requested - $release!"
    echo "You must specify a release number from the tag list: $tags"
    echo "If a recent zimbra release is not in the tags list then re-run the script with option"
    echo "  --tags/--tags9/--tags8 as appropriate to update your local tags_for_nn.txt file"
    exit 0
  else
    if [ -n "$earlier_releases" ]; then
      # There are earlier_releases. Append release[,]earlier_releases to make new tags string for building
      tags="$release,$earlier_releases"
    else
      # There are no earlier_releases. Set tags string to release for building
      tags="$release"
    fi
    d_echo "Building $release!"
    d_echo "Tags for build: $tags"
    echo "$tags"
  fi
}

#==================================================================================
function d_echo() {
    if [ "$debug" -eq 1 ]; then
        echo "$@" >&2
    fi
}

#==================================================================================

function usage() {
   echo "
        $0
           --version [10.1|10.0|9.0|8.8.15]  #return all tags for version
           --version 10.0.8             #return tags for specific version
           --debug                      #extra output
           -V                           # Version of script

      Example usage:
       $0 --version 10.1.1        # return all tags for version 10.1 (compaitbility with zimbra_tag_helper functions)
       $0 --version 10.1          # return all tags for version 10.1 (compaitbility with zimbra_tag_helper functions)
       $0 --version 10.0          # return all tags for version 10.0 (compaitbility with zimbra_tag_helper functions)
       $0 --version 9.0           # return all tags for version 9.0 (compaitbility with zimbra_tag_helper functions)
       $0 --version 10.0.2        # return only tags for version 10.0.2 and not all tags associated with version 10
       $0 --version 9.0.0.p38     # return only tags for 9.0.0.p38
       $0 --version 8.8.15.p46    # return only tags for 8.8.15.p46
   "
}

# extra verbose
debug=0
scriptVersion=1.3

# END DUPS - don't copy to build_zimbra.sh
#==============================================================================================================

#-----------------------------------------------------------------------------------------------------------
# Function to fetch and sort version tags from a remote repository accurately
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

#-----------------------------------------------------------------------------------------------------------

# Custom Perl script to sort version tags
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

#-----------------------------------------------------------------------------------------------------------

# Function to generate repository list from zm-build instructions
function generate_repo_list() {
    local zm_build_dir="./zm-build/instructions"
    local repo_list_file="$zm_build_dir/FOSS_repo_list.pl"
    local remote_list_file="$zm_build_dir/FOSS_remote_list.pl"
    local default_remote="gh-zm"

    if [[ ! -f $repo_list_file || ! -f $remote_list_file ]]; then
        echo "Required instruction files not found!"
        return 1
    fi

    perl -e '
        use strict;
        use warnings;
        use Data::Dumper;

        my ($repo_list_file, $remote_list_file, $default_remote) = @ARGV;

        # Read and parse the remote list file
        open my $remote_fh, "<", $remote_list_file or die "Cannot open $remote_list_file: $!";
        my %remote_entries;
        while (<$remote_fh>) {
            if (/\"([^\"]+)\"[^\"]*\"([^\"]+)\"/) {
                $remote_entries{$1} = $2;
            }
        }
        close $remote_fh;

#        print STDERR "Remote entries:\n";
#        print STDERR Dumper(\%remote_entries);

        # Read and parse the repo list file
        open my $repo_fh, "<", $repo_list_file or die "Cannot open $repo_list_file: $!";
        my @repo_entries;
        while (<$repo_fh>) {
            if (/name\s*=>\s*\"([^\"]+)\"/) {
                my $repo_name = $1;
                my $remote_name = $default_remote;
                if (/remote\s*=>\s*\"([^\"]+)\"/) {
                    $remote_name = $1;
                }
                push @repo_entries, { name => $repo_name, remote => $remote_name };
            }
        }
        close $repo_fh;

#        print STDERR "Repo entries:\n";
#        print STDERR Dumper(\@repo_entries);

        # Generate repository URLs
        foreach my $entry (@repo_entries) {
            my $repo_name = $entry->{name};
            my $remote_name = $entry->{remote};
            if (exists $remote_entries{$remote_name}) {
                my $url_prefix = $remote_entries{$remote_name};
                $url_prefix =~ s,/*$,,;  # Remove trailing slashes
                print "$url_prefix/$repo_name.git\n";
            } else {
                print STDERR "No valid remote for $repo_name\n";
            }
        }
    ' "$repo_list_file" "$remote_list_file" "$default_remote"
}

#-----------------------------------------------------------------------------------------------------------

# Function to find the latest tag
function find_latest_tag() {
    local repo_url=$1
    local pattern=$2
    local specific_tag=$3

    # Hard-coded return for 8.8.15
    if [[ "$specific_tag" == "8.8.15" ]]; then
        d_echo "*********** returning [8.8.15.p45] ****************"
        echo "8.8.15.p45"
        return
    fi

    # Fetch and filter the tags, ignoring 'beta', 'U20', and similar words
    tags=$(git ls-remote --tags "$repo_url" | awk '{print $2}' | grep -E "^refs/tags/$pattern" | grep -v '\^{}' | sed 's|refs/tags/||' | grep -vE 'beta|U20|RRHEL8')

    d_echo "Running command: git ls-remote --tags \"$repo_url\" | awk '{print \$2}' | grep -E \"^refs/tags/$pattern\" | grep -v '\\^{}' | sed 's|refs/tags/||' | grep -vE 'beta|U20|RRHEL8'"
    #d_echo "tags is: $tags"

    latest_tag=$(echo "$tags" | perl -e '
        use strict;
        use warnings;



        sub version_cmp {
            my ($a, $b) = @_;
            my @a_parts = split /(\d+|\D+)/, lc($a);  # Split and lowercase for consistent comparison
            my @b_parts = split /(\d+|\D+)/, lc($b);  # Split and lowercase for consistent comparison

            for (my $i = 0; $i < @a_parts && $i < @b_parts; $i++) {
                if ($a_parts[$i] =~ /^\d+$/ && $b_parts[$i] =~ /^\d+$/) {
                    return $a_parts[$i] <=> $b_parts[$i] if $a_parts[$i] != $b_parts[$i];
                } elsif ($a_parts[$i] =~ /^\d+$/ && $b_parts[$i] !~ /^\d+$/) {
                    return 1; # Numeric parts are greater than non-numeric
                } elsif ($a_parts[$i] !~ /^\d+$/ && $b_parts[$i] =~ /^\d+$/) {
                    return -1; # Non-numeric parts are less than numeric
                } else {
                    my $cmp = lc($a_parts[$i]) cmp lc($b_parts[$i]);
                    return $cmp if $cmp != 0;
                }
            }
            return @a_parts <=> @b_parts;
        }

        my $debug = shift @ARGV;        # Get the debug value from the arguments
        my $specific_tag = shift @ARGV;
        my @versions = <STDIN>;
        chomp(@versions);
        @versions = sort { version_cmp($a, $b) } @versions;

        # %%% Debugging: Print sorted versions
        if ($debug == 1) {
           print STDERR "Sorted versions: ", join(", ", @versions), "\n";
        }

        # Select the highest version less than or equal to specific_tag, or the highest overall
        my $latest = $versions[-1]; # Start with the highest sorted version
        foreach my $version (reverse @versions) {
            if (version_cmp($version, $specific_tag) <= 0) {
                $latest = $version;
                last;
            }
        }
        print $latest, "\n";
    ' "$debug" "$specific_tag")

    d_echo "best branch for zm-build [$latest_tag]"
    echo "$latest_tag"
}

#-----------------------------------------------------------------------------------------------------------

# clone the repository with the desired tag
function clone_repo() {
    local tag=$1
    local repo_url="git@github.com:Zimbra/zm-build.git"
    local clone_dir="zm-build"

    # make sure zm-build doesn't exist
    if [ -d "zm-build" ]; then
        /bin/rm -rf $clone_dir
        d_echo "$clone_dir directory removed."
    else
        d_echo "$clone_dir directory does not exist."
    fi


    d_echo "git clone --quiet --depth 1 --branch $tag $repo_url $clone_dir"
    if ! git clone --quiet --depth 1 --branch "$tag" "$repo_url" "$clone_dir" 2>/dev/null; then
        echo "Error: Failed to clone the repository. Exiting." >&2
        exit 1
    fi
}

#-----------------------------------------------------------------------------------------------------------

extract_version_pattern() {
    local version=$1
    local specific_version_flag=0

    # Split the input version by dots
    IFS='.' read -ra version_array <<< "$version"
    major="${version_array[0]}"
    minor="${version_array[1]}"
    rev="${version_array[2]}"
    extra="${version_array[3]}"

    # Determine the version pattern based on the segments
    if [ -n "${major}" ] && [ -n "${minor}" ] && [ -n "${rev}" ]; then
        if [ "${major}" -eq 8 ] && [ "${minor}" -eq 8 ] && [ "${rev}" -eq 15 ] && [ -z "${extra}" ]; then
            # Handle version pattern 8.8.15 as a general version
            specific_version_flag=0
            echo "${major}.${minor}.${rev}"
        else
            # Handle other specific versions (including 8.8.15.p40, 9.0.0.p28)
            specific_version_flag=1
            echo "${major}.${minor}.${rev}"
        fi
    elif [ -n "${major}" ] && [ -n "${minor}" ]; then
        # Handle version patterns like 10.1 or 10.0 (general versions)
        specific_version_flag=0
        echo "${major}.${minor}"
    else
        echo "Invalid version pattern"
    fi

    return $specific_version_flag
}

#-----------------------------------------------------------------------------------------------------------
#
# main()
# 

unique_tags=()                  # Array to hold unique tags

args=$(getopt -l "help,clean,version:,debug" -o "hV" -- "$@")
eval set -- "$args"

# Now process each option in a loop
while [ $# -ge 1 ]; do
        case "$1" in
                --)
                    # No more options left.
                    shift
                    break
                    ;;
                --debug)
                    debug=1
                    shift
                    ;;
                -V)
                    echo "Version: $scriptVersion"
                    exit 0
                    ;;
                --version)
                    version=$2
                    shift 2
                    ;;
                -h|--help)
                    usage
                    exit 0
                    ;;
        esac
done

if [[ -z "$version" ]]; then
    echo "build_zimbra.sh: Version not specified"
    echo "Try $0 --help for more information."
    exit 1
fi

# 
# Logic:
#   Step1: get our version we want tags for
#   Step2: find the highest tag we can find for this version
#   Step3: git clone zm-build using this tag
#   Step4: get a list of URL's for the repositories that make up the build
#   Step5: grab all the tags from these repositories
#   Step6: create a desending list of these tags to build the version

# extract version 10.1,10.0,9.0.0, 8.8.15 from version
#  Note: $showAll will be 1 if an exact version is required.
#
# Step1:
#
version_pattern=$(extract_version_pattern $version)
showAll=$?

d_echo "Version pattern: $version_pattern showAll: $showAll"
d_echo "Release to build: $version"


# specific version but chicken and egg problem when we don't have specific version
#
# Step2: find latest branch for the version we provide
desired_tag=$(find_latest_tag "https://github.com/Zimbra/zm-build" "$version_pattern" "$version")

# Step 3: clone that branch
d_echo "git clone https://github.com/Zimbra/zm-build.git with branch $desired_tag"
clone_repo "$desired_tag"

#
# Step 4:
#
   # generate a list of repositories that build.pl will use
   repo_list=$(generate_repo_list)
   if [[ $? -ne 0 ]]; then
      echo "Failed to generate repository list."
      exit 1
   fi


#
# Step 5:
#
    # Iterate through this list of repositories and grab any tags associated with them
    print_once=false
    while IFS= read -r repo_url
    do
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
    done <<< "$repo_list"

    # create the sorted list
    sorted_unique_tags=$(custom_sort_versions "${unique_tags[@]}")
    combined_tags=$(IFS=, ; echo "${sorted_unique_tags[*]}")

#
# Step 6:
#

   # Check if we  want all the tags or a specific branch is 1 or 0
   if [ $showAll -eq 0 ]; then
       d_echo "A specific version was not provided."
       echo "$combined_tags"
   else
       d_echo "A specific version was provided."
       release=$version
       tags=$combined_tags
       # set 2 variables above and output only the acceptable tags for the version to build
       strip_newer_tags
   fi

exit 0
