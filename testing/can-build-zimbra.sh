#!/usr/bin/env bash

ZIMBRA_FOSS_WIKI_URL="https://wiki.zimbra.com/wiki/Zimbra_Foss_Source_Code_Only_Releases"

# ----------------------------------------------------------
# can_build_zimbra <version>
#
# DEFAULT = ALLOW (buildable)
# ONLY BLOCK IF:
#   - A matching <tr> exists in the wiki table
#   - AND the LAST <td> contains 'N/A'
#
# The version string is used EXACTLY as passed.
# No normalization or stripping of .pNN suffixes.
# ----------------------------------------------------------
can_build_zimbra() {
  local version="$1"
  local page
  local last_col

  if [[ -z "$version" ]]; then
    echo "ERROR: can_build_zimbra() requires a version string" >&2
    return 2
  fi

  # Fetch wiki page (fail-open: if fetch fails, default to ALLOW)
  if ! page="$(curl -fsSL "$ZIMBRA_FOSS_WIKI_URL" 2>/dev/null)"; then
    echo "⚠️  WARNING: Unable to fetch wiki page." >&2
    echo "⚠️  DEFAULT ALLOW: Assuming '$version' CAN be built." >&2
    return 0
  fi

  # Extract the last <td> value from the <tr> that contains our version.
  # Strategy:
  #   1. Read entire page as single string (slurp mode: -0777)
  #   2. Find <tr>...</tr> containing <td>VERSION</td>
  #   3. Extract all <td>...</td> from that row and get the last one
  #   4. Strip HTML tags to get the text content
  #
  # We use perl for robust multi-line handling and regex matching.
  last_col="$(echo "$page" | SEARCH_VERSION="$version" perl -0777 -ne '
    # Find the <tr> that contains <td>VERSION</td> (exact match)
    my $search_version = quotemeta($ENV{SEARCH_VERSION});
    if (m{<tr\b[^>]*>.*?<td[^>]*>\s*$search_version\s*</td>.*?</tr>}si) {
      my $row = $&;
      # Extract all <td>...</td> cells from this row
      my @cells = ($row =~ m{<td[^>]*>(.*?)</td>}gsi);
      if (@cells) {
        # Get the last cell
        my $last = $cells[-1];
        # Strip any remaining HTML tags
        $last =~ s{<[^>]*>}{}g;
        # Trim whitespace
        $last =~ s{^\s+|\s+$}{}g;
        print $last;
      }
    }
  ')"

  # If we didn't find a matching row, default to ALLOW
  if [[ -z "$last_col" ]]; then
    return 0
  fi

  # If last column is N/A → still embargoed / NE-only → BLOCK
  if [[ "$last_col" == "N/A" ]]; then
    return 1
  fi

  # Otherwise → buildable → ALLOW
  return 0
}

# ----------------------------------------------------------
# Stand-alone execution mode
# ----------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  if [[ -z "$1" ]]; then
    echo "Usage:"
    echo "  $0 <version>"
    echo ""
    echo "Examples:"
    echo "  $0 10.1.7"
    echo "  $0 10.1.15"
    echo "  $0 9.0.0.p46"
    exit 2
  fi

  VERSION="$1"

  if can_build_zimbra "$VERSION"; then
    echo "✅ YES — '$VERSION' CAN be built."
    exit 0
  else
    echo "❌ NO — '$VERSION' is still embargoed (last column = N/A)."
    exit 1
  fi
fi
