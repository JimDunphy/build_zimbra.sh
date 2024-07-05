#!/bin/bash

# Function to generate repository list from zm-build instructions
generate_repo_list() {
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

# Call the function and capture its output
repo_list=$(generate_repo_list)
if [[ $? -ne 0 ]]; then
    echo "Failed to generate repository list."
    exit 1
fi

for repo_url in "${repo_list[@]}"; do
    #fetch_ordered_tags "$repo_url"
    echo "$repo_url"
done


# Output the repository list for debugging purposes
#echo "$repo_list"

