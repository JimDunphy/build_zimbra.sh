#!/bin/bash 

#
# Author: J Dunphy 3/14/2024
#
# Purpose:  Build a zimbra FOSS version based on latest tags in the Zimbra FOSS github for version 8.8.15, 9.0.0 or 10.0.0
#               The end result is there will be a tarball inside the BUILDS directory that can be installed which contains a install.sh script
#
# Documentation: https://wiki.zimbra.com/wiki/JDunphy-CompileZimbraScript
#
# CAVEAT: Command option --init needs to run as root. Script uses sudo and prompts user when required.
#
#         %%%
#         --tags,--tags9, --tags8 do not work with dry-run. The issue is that we have a cached version of the tags. To generate new tags, takes
#              some time but would be required to figure out tags for a --dry-run for example. Therefore, we exit on tags eventhough --dry-run
#              was specified. We will however have a new cached list of tags that future builds can use. Chicken/Egg problem for --dry-run.
#
#         .build.builder file is populated with a starting alphanumeric string provided using the --builder option or defaulting to FOSS if none is provided
#                            builder can be changed at any time using --builder alphanumeric
#         .build.number file is populated with a starting build in the format IIInnnn where III is a three digit builder id number, greater 
#                            than 100 to avoid dropping digits, and nnnn is a starting baseline build counter. e.g. 1011000
#                            The number will be incremented before the build so the first build would be 1010001. File will be created
#                            automatically but can also be done manually.  builderID can be changed at any time using --builderID \d\d\d
#
#                            Registered Builders
#                            101 - FOSS and build_zimbra.sh
#                            102 - VSherwood
#                            103 - JDunphy
#                            150 - Generic
#
# Edit: V Sherwood 4/5/2024
#         Enhance script so that specific releases can be requested rather than just the latest release of a particular Zimbra series
#       J Dunphy  4/16/2024 Ref: https://forums.zimbra.org/viewtopic.php?p=313419#p313419
#         --builder switch and some code recommended from V Sherwood. 
#       V Sherwood 4/18/2024
#         Store .build.number, and add the Requested Tag, git Cloned Tag and Builder Identifier to BUILD_RELEASE 
#       J Dunphy 4/21/2024
#         Cleanup and addition of --builderID 
#       V Sherwood 4/22/2024
#         Store .build.builder, default to FOSS if file not found and --builder option not supplied 
#         Allow --clean to be specified with --version
#

scriptVersion=2.0
copyTag="0.0"
tag="0.0"
default_builder="FOSS"
default_number=1011000
build_number_file=".build.number"
builder_name_file=".build.builder"
debug=0

# Static Tag files
tagBuilderScript="testing/build_tags_test.sh"
tagFileName10_1="tags_for_10_1.txt"
tagFileName10_0="tags_for_10_0.txt"
tagFileName9_0="tags_for_9_0.txt"
tagFileName8_8_15="tags_for_8_8_15.txt"

function d_echo() {
    if [ "$debug" -eq 1 ]; then
        echo "$@" >&2
    fi
}


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

    d_echo "clone_repo(): tag [$tag] repo_url [$repo_url] clone_dir [$clone_dir]"

    # make sure zm-build doesn't exist
    if [ -d "zm-build" ]; then
        /bin/rm -rf $clone_dir
        d_echo "$clone_dir directory removed."
    else
        d_echo "$clone_dir directory does not exist."
    fi


    d_echo "clone_repo(): git clone --quiet --depth 1 --branch $tag $repo_url $clone_dir"
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


#---------------------------------------------------------------------------------------------------

function extract_version_pattern() {
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



#
# build.pl uses this construct to clone repositories
#    % git clone --depth=1 -b 10.0.0-GA repo_name.git repo_dir
# A problem arises when there are multiple tags for the same detached head state.
# examples: zm-charset
#
function show_repository_clone_tag() {

   if [ ! -d zm-zcs ]; then 
      echo "You need to build a version before running this"
      echo "  try: $0 --version 10"
      exit 1
   fi 

   # Header for the output
   printf "%-20s %-30s %-20s\n" "Tag Name" "Formatted Date" "Directory"

   for dir in zm* ja* neko* ant* ical*
   do

      # %%%
      # Could not find git command line option to determine which tag the repository was cloned with
      # when multiple tags at the same detached head. Which one is correct?
      # they use this construct: git clone --depth=1 -b 10.0.0-GA repo_name.git repo_dir
      # example: zm-charset showing this issue.
      # a grep showed that .git/config contained the tag used in the clone.
      line=$(grep -R 'fetch = +refs/tags/' "$dir/.git/config")
      repo=$(echo $line | cut -d'/' -f1)  # Extracts the repository directory name
      tag=$(echo $line | sed -n 's/.*refs\/tags\/\([^:]*\).*/\1/p')  # Extracts the tag name

      cd $dir
      # An oddcase where the above observation didn't work and does work as expected
      if [ $dir == "zm-mailbox" ]; then
         tag=$(git describe --tags --exact-match)
      fi
      read -r timestamp tagname <<< $(git tag --format='%(creatordate:unix)%09%(refname:strip=2)' --sort=-taggerdate | grep "$tag" | head -n 1)
      formatted_date=$(date -d "@$timestamp" '+%Y-%m-%d %H:%M:%S')  # Formats the timestamp into a human-readable date
      cd ..

      printf "%-20s %-30s %-20s\n" "$tag" "$formatted_date" "$dir"
   done
}

# show the latest tag with each repository
function show_repository_tags() {

   if [ ! -d zm-zcs ]; then 
      echo "You need to build a version before running this"
      echo "  try: $0 --version 10"
      exit 1
   fi 

   # Header for the output
   printf "%-20s %-30s %-20s\n" "Tag Name" "Formatted Date" "Directory"

   for dir in zm* ja* neko* ant* ical*
   do
       cd $dir
       # Get the most recent tag and its creation timestamp
       read -r timestamp tagname <<< $(git tag --format='%(creatordate:unix)%09%(refname:strip=2)' --sort=-taggerdate | head -n 1)
   
       # Convert Unix timestamp to a human-readable date
       formatted_date=$(date -d @$timestamp '+%Y-%m-%d %H:%M:%S')
   
       # Output the values in tabular format, putting the directory name last
       printf "%-20s %-30s %-20s\n" "$tagname" "$formatted_date" "$dir"
       cd ..
   done
}

# read the first line from a file and set builder
function read_builder() {

    # if we don't have a .build.builder then create the default file
    if [ ! -f "$builder_name_file" ]; then update_builder; fi

    # establish the builder for this
    if [ -f "$builder_name_file" ]; then
        # Read the first line of the file, confirm it is alpha-numreic
        builder=$(head -n 1 "$builder_name_file")
        d_echo "Found builder is $builder_id"
        if [ -z "$builder" ]; then
            echo "No alpha-numeric builder name found at the start of the file."
            #return 1  # Return a non-zero status to indicate failure
            exit
        fi
    fi
}

# update .build.builder or create it with defaults
function update_builder() {
    if [ ! -f "$builder_name_file" ]; then
        # File does not exist, create it and populate it with the default builder
        echo $default_builder > $builder_name_file
    else
        # File exists, overwrite it with $builder
        echo $builder > $builder_name_file
    fi
}

# validate input is alphanumeric
function is_alphanumeric() {
    if [[ "$1" =~ [^a-zA-Z0-9] ]]; then
      return 1
    fi
    return 0
}

# read the first three digits from a file and set builder_id
function read_builder_id() {

    # if we don't have a builder_id then create the default and file
    if [ ! -f "$build_number_file" ]; then update_builder_no; fi

    # establish the builder_id for this
    if [ -f "$build_number_file" ]; then
        # Read the first line of the file, extract the first three digits
        builder_id=$(head -n 1 "$build_number_file" | grep -o '^[0-9]\{3\}')
        d_echo "Found builder_id is $builder_id"
        if [ -z "$builder_id" ]; then
            echo "No three-digit number found at the start of the file."
            #return 1  # Return a non-zero status to indicate failure
            exit
        fi
    fi
}

# update .build.number or create it with defaults
function update_builder_no() {
    if [ ! -f "$build_number_file" ]; then
        # File does not exist, create it and populate it with the default number
        echo $default_number > $build_number_file
    else
        # File exists, replace the first three digits with the value of $builder_id
        sed -i "s/^[0-9]\{3\}/$builder_id/" $build_number_file
    fi
}

# validate input is a three-digit number - with first digit non-zero
function is_three_digit_number() {
    case $1 in
        [1-9][0-9][0-9]) return 0 ;;  # exactly three digits, with first digit non-zero
        *)
          return 1 ;;                # not exactly three digits, or first digit is zero
    esac
}

# %%% no longer used
function find_tag() {
    # find tag that we cloned the zm-build with
    if [ -d "zm-build" ] ; then 
       pushd zm-build

       # Get the current branch name
       copyTag=$(git describe --tags --exact-match)

       # Print the current branch
       echo "Current branch is: $copyTag"
      popd
    fi
}

# Fine the latest zm-build we can check out
function clone_until_success() {
  local tags=$1
  local repo_url=$2
  
  IFS=',' read -ra TAG_ARRAY <<< "$tags"
  for tag in "${TAG_ARRAY[@]}"; do
    echo "Attempting to clone branch $tag..."
    if git clone --depth 1 --branch "$tag" "git@github.com:Zimbra/zm-build.git"; then
      echo "Successfully cloned branch $tag"
      echo "git clone --depth 1 --branch $tag git@github.com:Zimbra/zm-build.git"
      copyTag=$tag
      return
    else
      echo "Failed to clone branch $tag. Trying the next tag..."
    fi
  done
  
  echo "All attempts failed. Unable to clone the repository with the provided tags."
}

# Tools that make this possible
function clone_if_not_exists() {
  # Extract the repo name from the URL
  repo_name=$(basename "$1" .git)

  # Check if the directory already exists
  if [ -d "$repo_name" ]; then
    echo "Repository $repo_name already exists locally."
    return
  else
    # Clone the repository
    git clone "$1"
    echo "Repository $repo_name cloned successfully."
  fi
}

# Run one time only
function init ()
{
   # Get supporting scripts that we will use
   clone_if_not_exists https://github.com/ianw1974/zimbra-build-scripts
   clone_if_not_exists https://github.com/maldua/zimbra-tag-helper

   # We need another filter script for verison 8.8.15. 
   cp zimbra-tag-helper/zm-build-filter-tags-9.sh zimbra-tag-helper/zm-build-filter-tags-8.sh
   sed -i 's/MAIN_BRANCH="9.0"/MAIN_BRANCH="8.8.15"/' zimbra-tag-helper/zm-build-filter-tags-8.sh

   echo "Will need to run next command as root to install system dependicies and tools"
   sudo zimbra-build-scripts/zimbra-build-helper.sh --install-deps
}


function usage() {
   echo "
        $0
        --init                     #first time to setup envioroment (only once)
        --version [10.1|10.0|9.0|8.8.15]         #build release 8.8.15 or 9.0.0 or 10.0.0
        --version 10.0.8           #build release 10.0.8
        --debug                    #extra output - use as 1st argument
        --clean                    #remove everything but BUILDS
        --tags                     #create tag filess for all versions possible
        --tags10.0                 #create tags for version 10.0
        --tags10.1                 #create tags for version 10.1
        --tags8.8.15               #create tags for version 8
        --tags9.0                  #create tags for version 9
        --upgrade                  #echo what needs to be done to upgrade the script
        --builder foss             # an alphanumeric builder name, updates .build.builder file with value
        --builderID [\d\d\d]       # 3 digit value starting at 101-999, updates .build.number file with value
        -V                         #version of this program
        --dry-run                  #show what we would do
        --show-tags                #show latest tag for each repositories
        --show-tags | grep 10.0.8  #show latest tag for each repositories with 10.0.8
        --show-cloned-tags         #show tag of each cloned repository used for build
        --help

       Example usage:
       $0 --init               # first time only
       $0 --upgrade            # show how get latest version of this script
       $0 --upgrade | sh       # overwrite current version of script with latest version from github
       $0 --version 10.0       # build latest patch version 10.0 according to tags
       $0 --version 10.1       # build latest patch version 10.1 according to tags
       $0 --version 10.0.6     # build version 10.0.6
       $0 --version 10.1.0     # build version 10.1.0

       $0 --clean; $0 --version 9.0     #build version 9 
       $0 --clean; $0 --version 8.8.15  #build version 8 
       $0 --clean; $0 --version 10.0.9 --dry-run  #see how to build version 10.0.9
       $0 --clean; $0 --version 10.0.8  #build version 10.0.8
       $0 --clean; $0 --version 10.1.1  #build version 10.1.1

      WARNING: ********************************************************************************
        the tags are cached. If a new release comes out, you must explicity do this before building if you are using the same directory:

       $0 --clean; $0 --tags

      This is because the tags are cached in a file and need to recalculated again.
      *****************************************************************************************
  "
}

function isRoot() {
   # need to run as root because local cache has perm problem
   ID=`id -u`
   if [ "x$ID" != "x0" ]; then
     echo "Run as root!"
     exit 1
   fi
}

# Function to run a command with asynchronous dots display
run_with_dots() {
  local command="$1"
  local output_file="$2"

  # Function to display dots
  show_dots() {
    while true; do
      printf "."
      sleep 1
    done
  }

  # Start the dots in the background
  show_dots &
  local dots_pid=$!

  # disown dots process so shell doesn't track it and complain on exit
  disown  $dots_pid

  # Execute the command and redirect output
  if [ -d $output_file ] ; then /bin/rm -rf $output_file; fi
  eval "$command > $output_file" 2> /dev/null 
  local status=$?

  # Stop the dots
  kill $dots_pid 2> /dev/null

  # Ensure a newline after dots
  echo ""

  #Check the exit status
#  if [ $? -eq 0 ]; then
#    echo "Command executed successfully."
#  else
#    echo "Command failed."
#    exit
#  fi

  # Return the status of the command
  return $status
}

function get_inline_tags ()
{
  showAll=$1
  version_pattern=$2
  version=$3
#  tags=$4
#  copyTag=$5




#
# Step1:
#
#version_pattern=$(extract_version_pattern $version)
#showAll=$?

# specific version but chicken and egg problem when we don't have specific version
#
# Step2: find latest branch for the version we provide
desired_tag=$(find_latest_tag "https://github.com/Zimbra/zm-build" "$version_pattern" "$version")
copyTag="$desired_tag"

d_echo "showAll [$showAll] version_pattern [$version_pattern] version [$version] tags [$tags] copyTag [$desired_tag]"

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
       #%%%echo "$combined_tags"
       tags="$combined_tags"
   else
       d_echo "A specific version was provided."
       release=$version
       tags=$combined_tags
       # set 2 variables above and output only the acceptable tags for the version to build
       #strip_newer_tags
       #tags=$(strip_newer_tags)
   fi

   d_echo "+++ tags [$tags] copyTag [$copyTag]"
}


# Build Static files containing tags for releases to build
function get_tags ()
{
  case "$1" in
      "10.0")
           d_echo "Building tags for version 10.0"
           run_with_dots "$tagBuilderScript --version 10.0" "$tagFileName10_0"
           ;;
      "10.1")
           d_echo "Building tags for version 10.1"
           run_with_dots "$tagBuilderScript --version 10.1" "$tagFileName10_1"
           ;;
      "9.0")
           d_echo "Building tags for version 9.0"
           run_with_dots "$tagBuilderScript --version 9.0" "$tagFileName9_0"
           ;;
      "8.8.15")
           d_echo "Building tags for version 8.8.15"
           run_with_dots "$tagBuilderScript --version 8.8.15" "$tagFileName8_8_15"
           ;;
      *)
           echo "Building Static tag files - should take about 40-45 seconds"
           d_echo "Building tags for version 10.1"
           run_with_dots "$tagBuilderScript --version 10.1" "$tagFileName10_1"
           d_echo "Building tags for version 10.0"
           run_with_dots "$tagBuilderScript --version 10.0" "$tagFileName10_0"
           d_echo "Building tags for version 9.0"
           run_with_dots "$tagBuilderScript --version 9.0" "$tagFileName9_0"
           d_echo "Building tags for version 8.8.15"
           run_with_dots "$tagBuilderScript --version 8.8.15" "$tagFileName8_8_15"

           if [ $debug -eq 1 ]; then ls -l tags*;fi
           ;;
  esac

}

function strip_newer_tags()
{
  # Trims off the leading tags that are newer than the requested release
  
  # Add [,] to both strings to avoid matching extended release numbers. e.g. 10.0.0-GA when searching for 10.0.0, or 9.0.0.p32.1 when searching for 9.0.0.p32
  tagscomma="$tags,"
  releasecomma="$release,"

  d_echo "tagscomma $tagscomma releasecomma $releasecomma"

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
  fi
}

# Pads version components from 'release' and zm_build branch represented by 'copyTag' to two digits and constructs 
#    formatted 'Build Tag' and 'Clone Tag'.
function zero_pad_tag_and_clone_versions()
{
# check if a specific release version was requested - Format n.n.n[.p[.n]] 

echo "Release $release"
IFS='.' read -ra version_array <<< "$release"
major="00${version_array[0]}"
minor="00${version_array[1]}"
patch="00${version_array[2]}"
build_tag="${major: -2}${minor: -2}${patch: -2}${version_array[3]}${version_array[4]}"
echo "Build Tag $build_tag"
echo "CopyTag $copyTag"
IFS='.' read -ra version_array <<< "$copyTag"
major="00${version_array[0]}"
minor="00${version_array[1]}"
patch="00${version_array[2]}"
clone_tag="${major: -2}${minor: -2}${patch: -2}${version_array[3]}${version_array[4]}"
echo "Clone Tag $clone_tag"
}

#======================================================================================================================
#
#   main program logic starts here
#
#======================================================================================================================

dryrun=0
args=$(getopt -l "init,show-tags,show-cloned-tags,dry-run,tags,tags8,tags8.8.15,tags9,tags9.0,tags10.0,tags10.1,help,clean,upgrade,version:,builder:,builderID:,debug" -o "hV" -- "$@")
eval set -- "$args"

# Now process each option in a loop
while [ $# -ge 1 ]; do
        case "$1" in
                --)
                    # No more options left.
                    shift
                    break
                    ;;
                --init)
                    init
                    exit 0
                    ;;
                --show-tags)
                    show_repository_tags
                    exit 0
                    ;;
                --show-cloned-tags)
                    show_repository_clone_tag
                    exit 0
                    ;;
                --debug)
                    debug=1
                    shift
                    ;;
                --builderID)
                    if [ -z "$2" ] || ! is_three_digit_number "$2"; then
                        echo "Error: --builderID requires a three-digit numeric argument, with the first digit non-zero."
                        exit 1
                    fi
                    builder_id=$2
                    update_builder_no		# will create if doesn't exist
                    shift 2 
                    ;;
                --upgrade)
                    echo cp $0 $0.$scriptVersion
                    echo wget -O $0 'https://raw.githubusercontent.com/JimDunphy/ZimbraScripts/master/src/build_zimbra.sh' 
                    exit 0
                    ;;
                --dry-run)
                    dryrun=1
                    shift
                    ;;
                -V)
                    echo "Version: $scriptVersion"
                    exit 0
                    ;;
                --clean)
                    #     currently removing zm-build in explict tags,tags9 option. What about --dry-run?
                    clean=true
                    echo "Cleaning up ..."
                    /bin/rm -rf zm-* j* neko* ant* ical* .staging*
                    echo "Done!"
                    shift
                    ;;
                --version)
                    version=$2
                    shift 2
                    ;;
                --builder)
                    if [ -z "$2" ] || ! is_alphanumeric "$2"; then
                        echo "Error: --builder requires an alphanumeric argument."
                        exit 1
                    fi
                    builder=$2
                    update_builder		# will create if doesn't exist
                    shift 2
                    ;;
                --tags)
                    get_tags "all"
                    exit 0
                    ;;
                --tags10.0)
                    get_tags "10.0"
                    exit 0
                    ;;
                --tags10.1)
                    get_tags "10.1"
                    exit 0
                    ;;
                --tags9*)
                    get_tags "9.0"
                    exit 0
                    ;;
                --tags8*)
                    get_tags "8.8.15"
                    exit 0
                    ;;
                -h|--help)
                    usage
                    exit 0
                    ;;
        esac
done

# %%% bug... --builder and --builderID will be updated even with dry-run. It happens in the switch statement.
# Processing continues with the only possible options to get here: --builder, --builderID, --clean, --version

# builderID and/or builder and/or clean should exit if they are not building a version.
if [[ (-n "$builder_id"  || -n "$builder" || -n "$clean") && -z "$version" ]]; then
    d_echo "quietly exiting as we only want to clean or set builder id/builder"
    exit 0
fi

if [[ -z "$version" ]]; then
    echo "build_zimbra.sh: Version not specified"
    echo "Try 'build_zimbra.sh --help' for more information."
    exit 1
fi

# Are we Building a specific version or the latest version?
version_pattern=$(extract_version_pattern $version)
specificVersion=$?	# specific version or build latest version

# Grab the tags for this version
#set -vx
#tags=$(get_inline_tags $specificVersion $version_pattern $version)
# tags is a comma seperated list of tags used to make a release to build
get_inline_tags $specificVersion $version_pattern $version #$tags $copyTag
copyTag=$desired_tag
d_echo "tags: [$tags] copyTags: [$copyTag]"
d_echo "Version pattern: $version_pattern specificVersion: $specificVersion"
d_echo "Release to build: $version"

# check if a specific release version was requested - Format n.n.n[.p[.n]] 
IFS='.' read -ra version_array <<< "$version"
major="${version_array[0]}"
minor="${version_array[1]}"
rev="${version_array[2]}"
d_echo "version $version major [$major], minor [$minor], revision [$rev]"


if [ $specificVersion -eq 0 ]; then
  d_echo "Requested latest Zimbra $major release and version $version"
else
  release="${version}"
  version="${major}.${minor}"	
  d_echo "Requested Zimbra release $release and version $version"
fi


case "$version" in
  "8.8"|"8.8.15"|"8.8*")
#    if [ ! -f $tagFileName8_8_15 ]; then get_tags "8.8.15"; fi
#    tags="$(cat $tagFileName8_8_15)"
    if [ $specificVersion -eq 1 ]; then
      strip_newer_tags
    else
      release=$(echo "$tags" | cut -d ',' -f 1)
    fi
    LATEST_TAG_VERSION=$(echo "$tags" | awk -F',' '{print $NF}')
    PATCH_LEVEL="GA"
    BUILD_RELEASE="JOULE"
    ;;
  "9.0")
#    if [ ! -f $tagFileName9_0 ]; then get_tags 9.0; fi
#    tags="$(cat $tagFileName9_0)"
#    if [ -n "$release" ]; then
    if [ $specificVersion -eq 1 ]; then
      strip_newer_tags
    else
      release=$(echo "$tags" | cut -d ',' -f 1)
    fi
    LATEST_TAG_VERSION=$(echo "$tags" | awk -F',' '{print $NF}')
    PATCH_LEVEL="GA"
    BUILD_RELEASE="KEPLER"
    ;;
  "10.0")
#    if [ ! -f $tagFileName10_0 ]; then get_tags 10.0; fi
#    tags="$(cat $tagFileName10_0)"
#    if [ -n "$release" ]; then
    if [ $specificVersion -eq 1 ]; then
      strip_newer_tags
    else
      release=$(echo "$tags" | cut -d ',' -f 1)
    fi
    LATEST_TAG_VERSION=$(echo "$tags" | cut -d ',' -f 1)
    PATCH_LEVEL="GA"
    BUILD_RELEASE="DAFFODIL"
    ;;
  "10.1")
#    if [ ! -f $tagFileName10_1 ]; then get_tags 10.1; fi
#    tags="$(cat $tagFileName10_1)"
#    if [ -n "$release" ]; then
    if [ $specificVersion -eq 1 ]; then
      strip_newer_tags
    else
      release=$(echo "$tags" | cut -d ',' -f 1)
    fi
    LATEST_TAG_VERSION=$(echo "$tags" | cut -d ',' -f 1)
    PATCH_LEVEL="GA"
    BUILD_RELEASE="DAFFODIL"
    ;;
  *)
    echo "Possible values: 8 or 9 or 10.0 or 10.1"
    exit
    ;;
esac


# pass these on to the Zimbra build.pl script
# 10.1.0 | 10.0.0 | 9.0.0 | 8.8.15 are possible values
TAGS_STRING=$tags
d_echo "tags: $TAGS_STRING"

# If zm-build folder exists, --clean wasn't run, build will fail, so abort. unless dry-run where we are not building
if [ -d zm-build ]; then
    if [ "$dryrun" -eq 0 ]; then
        echo "You must run the script with --clean option before each new build (even if rebuilding the same version)"
        echo "The zm-build process will fail if this is not done!"
        exit 1
    fi
    echo "Removing zm-build directory..."
    /bin/rm -rf zm-build
fi


# Find and clone zm-build with latest branch given version to build.
clone_until_success "$tags" >/dev/null 2>&1

# pads release version and zm_build branch to two digits and constructs formatted $build_tag and $clone_tag
zero_pad_tag_and_clone_versions

#---------------------------------------------------------------------
# .build.builder file contains the alphanumeric builder name to appear in the build log
#  If this file doesn't exist then create the file using the default builder name FOSS
#  If the file does exist then set $builder to the string in the first line
#---------------------------------------------------------------------
read_builder
# Add the Requested Tag, git Cloned Tag and Builder Identifier to BUILD_RELEASE.
# This will be used in naming the .tgz file output
BUILD_RELEASE="${BUILD_RELEASE}_T${build_tag}C${clone_tag}$builder"

#---------------------------------------------------------------------
# .build.number file contains 7 digits. The first 3 digits represent the builder_id and the other 4 the build no.
#  This file is passed to zm-build/build.pl that will look for it or creates it if absent. It will +1 increment contents.
#  If this file doesn't exist then create a default entry represent FOSS builder id + starting build no.
#  If the file does exist then set $builder_id to value of the first 3 digits
#---------------------------------------------------------------------
read_builder_id


# Build the source tree with the specified parameters
commands=$(cat << _END_OF_COMMANDS_
#!/bin/sh
git clone --depth 1 --branch "$tag" "git@github.com:Zimbra/zm-build.git"
cd zm-build
ENV_CACHE_CLEAR_FLAG=true ./build.pl --ant-options -DskipTests=true --git-default-tag="$TAGS_STRING" --build-release-no="$LATEST_TAG_VERSION" --build-type=FOSS --build-release="$BUILD_RELEASE" --build-thirdparty-server=files.zimbra.com --no-interactive --build-release-candidate=$PATCH_LEVEL
_END_OF_COMMANDS_
)

# Execute or dry-run
if [ $dryrun -eq 1 ]; then
  echo "$commands"
  exit 0
else
  eval "$commands"
  cd .. 
  cp ${build_number_file} .
fi

# Log the build
build="$(cat "$build_number_file")"
build_tgz="$(ls -1 BUILDS | grep FOSS-$build)"
build_ts="$(date +%Y%m%d-%H%M%S)"
if [[ -z "${build_tgz}" ]]; then
    build_tgz="Build failed!"
fi
echo "$build_ts  $build  $build_tgz" >> ./builds.log
# show completed builds
find BUILDS -name \*.tgz -print

exit 0
