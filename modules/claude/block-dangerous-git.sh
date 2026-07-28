# Runs under writeShellApplication (set -euo pipefail), hence the
# `|| true` guard where failing is fine (outside a repo).
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

block() {
  echo "BLOCKED: '$COMMAND' $1 The user has prevented you from doing this." >&2
  exit 2
}

# git push: allow non-force pushes to feature branches, but block force pushes
# and pushes that name a protected branch in the push command itself.
if echo "$COMMAND" | grep -qE '(^|[[:space:]&|;(])git[[:space:]]+push'; then
  if echo "$COMMAND" | grep -qE '(^|[[:space:]])(-f|--force|--force-with-lease)([[:space:]=]|$)'; then
    block "is a force push."
  fi
  if echo "$COMMAND" | grep -qE '(^|[[:space:]&|;(])git[[:space:]]+push([^&|;]*[[:space:]:/])(refs/heads/)?(master|main)([[:space:]&|;:]|$)'; then
    block "pushes a protected branch."
  fi
  exit 0
fi

DANGEROUS_PATTERNS=(
  "git reset --hard"
  "git clean -fd"
  "git clean -f"
  "git branch -D"
  "git checkout \."
  "git restore \."
  "reset --hard"
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
    echo "BLOCKED: '$COMMAND' matches dangerous pattern '$pattern'. The user has prevented you from doing this." >&2
    exit 2
  fi
done

exit 0
