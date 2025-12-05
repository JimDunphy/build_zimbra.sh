#!/usr/bin/env bash
# Usage:
#   eval "$(get_pimbra_tag_and_overrides BASE_VERSION)"
# After call, you get:
#   PIMBRA_TAG        — full tag, e.g. "10.1.10.p3" (or empty if none)
#   PIMBRA_OVERRIDES  — Git-overrides string, e.g.
#                      --git-overrides "zm-zcs-lib.remote=maldua-pimbra" \
#                      --git-overrides "zm-zcs-lib.tag=10.1.10.p3-maldua"
#
get_pimbra_tag_and_overrides() {
  local basever="$1"
  local zm_build_repo="https://github.com/maldua-pimbra/zm-build.git"
  local cfg_repo_raw="https://raw.githubusercontent.com/maldua-pimbra/maldua-pimbra-config"

  # 1) find highest pN tag for given basever
  # List remote tags; filter for tags like basever.pN; sort version-wise; pick highest
  local tag
  tag=$( git ls-remote --tags --refs "$zm_build_repo" \
        | awk '{print $2}' \
        | sed 's!refs/tags/!!' \
        | grep -E "^${basever}\.p[0-9]+$" \
        | sort -V \
        | tail -n1 )

  if [[ -z "$tag" ]]; then
    # No pimbra patch tag found for this base version
    export PIMBRA_TAG=""
    export PIMBRA_OVERRIDES=""
    return 1
  fi

  export PIMBRA_TAG="$tag"
  
  # 2) fetch config.build for that tag
  local cfg_url="${cfg_repo_raw}/${tag}/config.build"
  local cfgfile
  cfgfile=$(mktemp)
  if ! curl -fsSL "$cfg_url" -o "$cfgfile"; then
    echo "Warning: Pimbra config.build not found at $cfg_url" >&2
    export PIMBRA_OVERRIDES=""
    return 2
  fi

# 3) extract %GIT_OVERRIDES = ... tokens from config.build
#    This handles multiple overrides per line.
#
# Split each %GIT_OVERRIDES into separate tokens
# Drop everything before the first override
# Strip trailing comments
# Flatten to one space-separated line
# Trim whitespace
overrides=$(
  sed 's/%GIT_OVERRIDES[[:space:]]*=[[:space:]]*/\n/g' "$cfgfile" \
    | tail -n +2 \
    | sed 's/#.*$//' \
    | tr '\n' ' ' \
    | xargs
)


rm -f "$cfgfile"

if [[ -z "$overrides" ]]; then
  echo "Warning: No %GIT_OVERRIDES found in config.build for $tag" >&2
  export PIMBRA_OVERRIDES=""
  return 3
fi

# Build final command-line snippet:
# overrides now looks like:
#   maldua-pimbra.url-prefix=https://github.com/maldua-pimbra \
#   zm-web-client.remote=maldua-pimbra \
#   zm-web-client.tag=10.1.10.p3-maldua \
#   ...
local ov_str=""
for o in $overrides; do
  ov_str+="--git-overrides \"$o\" "
done
export PIMBRA_OVERRIDES="$ov_str"


}

BASEVER="10.1.10"        # e.g. given by user or derived
#BASEVER="10.1.9"        # e.g. given by user or derived
if get_pimbra_tag_and_overrides "$BASEVER"; then
  echo "Using Pimbra tag: $PIMBRA_TAG"
  echo "-----------"
  echo "Git overrides: $PIMBRA_OVERRIDES"
  echo "-----------"
  # Then clone Pimbra build repo:
  echo git clone --depth 1 --branch "$PIMBRA_TAG" https://github.com/maldua-pimbra/zm-build.git
  # And when you call build.pl (or build.sh), append:
  echo "-----------"
  #echo eval ./build.pl ${PIMBRA_OVERRIDES} ...
else
  echo "No Pimbra patch found for $BASEVER; proceeding with upstream build."
  # Upstream logic...
fi
