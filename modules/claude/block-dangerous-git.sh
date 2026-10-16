# Runs under writeShellApplication (set -euo pipefail), hence the
# `|| true` guard where failing is fine (outside a repo).
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

block() {
  echo "BLOCKED: '$COMMAND' $1 The user has prevented you from doing this." >&2
  exit 2
}

if echo "$COMMAND" | grep -qE '(^|[[:space:]&|;(])git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+worktree[[:space:]]+add'; then
  case "$CWD" in
    "$HOME"/Code/dotfiles | "$HOME"/Code/dotfiles/*) block "adds a worktree to dotfiles, which is edited in its main checkout." ;;
  esac
  if echo "$COMMAND" | grep -qE '(Code|worktrees)/dotfiles'; then
    block "adds a worktree to dotfiles, which is edited in its main checkout."
  fi
fi

# git push: allow feature-branch pushes and force-with-lease, but block plain
# force pushes and pushes that name a protected branch in the push command itself.
if echo "$COMMAND" | grep -qE '(^|[[:space:]&|;(])git[[:space:]]+push'; then
  if echo "$COMMAND" | grep -qE '(^|[[:space:]&|;(])git[[:space:]]+push[^&|;]*[[:space:]](-f|--force)([[:space:]=]|$)'; then
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
