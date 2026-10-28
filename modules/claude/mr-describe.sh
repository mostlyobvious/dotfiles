# Runs under writeShellApplication (set -euo pipefail): a missing file stops
# the script before anything reaches GitLab.
if [ "$#" -ne 2 ]; then
  echo "usage: mr-describe <iid> <file>" >&2
  exit 64
fi

iid=$1
file=$2
description=$(cat "$file")

if [ -z "$description" ]; then
  echo "mr-describe: $file is empty" >&2
  exit 1
fi

current=$(glab mr view "$iid" -F json | jq -r .description)
diff -u <(printf '%s\n' "$current") <(printf '%s\n' "$description") || true

glab mr update "$iid" --description "$description"

published=$(glab mr view "$iid" -F json | jq -r .description)
if [ "$published" != "$description" ]; then
  echo "mr-describe: !$iid description differs from $file after update" >&2
  diff -u <(printf '%s\n' "$description") <(printf '%s\n' "$published") >&2 || true
  exit 1
fi

echo "mr-describe: !$iid description matches $file"
