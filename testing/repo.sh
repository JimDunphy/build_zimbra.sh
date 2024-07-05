#!/bin/bash

generate_repo_urls() {
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

    #echo "Repository URLs have been saved to $output_file"
}

generate_repo_urls

# Display the contents of the output file
#echo "Contents of repo_urls.txt:"
cat repo_urls.txt
