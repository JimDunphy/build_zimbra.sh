#!/bin/bash

find_latest_tag() {
    local repo_url=$1
    local pattern=$2
    local specific_tag=$3

    # Fetch and filter the tags
    tags=$(git ls-remote --tags "$repo_url" | awk '{print $2}' | grep -E "^refs/tags/$pattern" | grep -v '\^{}' | sed 's|refs/tags/||')

#    echo "tags is: $tags"

    latest_tag=$(echo "$tags" | perl -e '
        use strict;
        use warnings;
        
        sub version_cmp {
            my ($a, $b) = @_;
            my @a_parts = split /(\d+|\D+)/, $a;
            my @b_parts = split /(\d+|\D+)/, $b;
            for (my $i = 0; $i < @a_parts && $i < @b_parts; $i++) {
                if ($a_parts[$i] =~ /^\d+$/ && $b_parts[$i] =~ /^\d+$/) {
                    return $a_parts[$i] <=> $b_parts[$i] if $a_parts[$i] != $b_parts[$i];
                } else {
                    return lc($a_parts[$i]) cmp lc($b_parts[$i]) if lc($a_parts[$i]) ne lc($b_parts[$i]);
                }
            }
            return @a_parts <=> @b_parts;
        }

        my $specific_tag = shift @ARGV;
        my @versions = <STDIN>;
        chomp(@versions);
        @versions = sort { version_cmp($a, $b) } @versions;

        #print "sorted versions: ", join(", ", @versions), "\n";  # Debugging

        my $latest = "No valid tag found";
        foreach my $version (@versions) {
            if (version_cmp($version, $specific_tag) <= 0) {
                $latest = $version;
            } else {
                last;
            }
        }
        print $latest, "\n";
    ' "$specific_tag")

    echo "$latest_tag"
}

# Example usage
latest_tag=$(find_latest_tag "https://github.com/Zimbra/zm-build" "10.0" "10.0.1")
echo "tag matching pattern '10.0' to build tag '10.0.1' is zm-build tag: $latest_tag"

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
