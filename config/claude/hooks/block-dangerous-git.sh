#!/bin/bash

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

block() {
  echo "BLOCKED: '$COMMAND' $1 The user has prevented you from doing this." >&2
  exit 2
}

# git push: allow non-force pushes to feature branches, but block force pushes
# and any push touching a protected branch.
if echo "$COMMAND" | grep -qE '(^|[[:space:]&|;(])git[[:space:]]+push'; then
  if echo "$COMMAND" | grep -qE '(^|[[:space:]])(-f|--force|--force-with-lease)([[:space:]=]|$)'; then
    block "is a force push."
  fi
  current=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [[ "$current" == master || "$current" == main ]] || echo "$COMMAND" | grep -qwE 'master|main'; then
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
