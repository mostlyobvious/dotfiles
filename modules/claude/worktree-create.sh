# Runs under writeShellApplication (set -euo pipefail). Claude Code's
# WorktreeCreate hook: it fully replaces the default `git worktree add`, so this
# script places the worktree under ~/Code/worktrees/<repo>/<slug>. The created
# path MUST be the last stdout line; all other output goes to stderr; any
# non-zero exit aborts creation.

INPUT=$(cat)
NAME=$(echo "$INPUT" | jq -r '.name')
CWD=$(echo "$INPUT" | jq -r '.cwd')

# The repo's primary working tree — our copy source and the basis for <repo> —
# regardless of whether Claude runs from a linked worktree.
COMMON_DIR=$(git -C "$CWD" rev-parse --path-format=absolute --git-common-dir)
MAIN_ROOT=$(dirname "$COMMON_DIR")
REPO=$(basename "$MAIN_ROOT")

SLUG=$(printf '%s' "$NAME" | tr -c '[:alnum:]._-' '-')
DEST="$HOME/Code/worktrees/$REPO/$SLUG"

# Base ref: origin's default branch (fresh). Fall back to HEAD if there's no origin.
ORIGIN_HEAD=$(git -C "$MAIN_ROOT" symbolic-ref --quiet refs/remotes/origin/HEAD || true)
if [ -z "$ORIGIN_HEAD" ]; then
  git -C "$MAIN_ROOT" remote set-head origin --auto >&2 || true
  ORIGIN_HEAD=$(git -C "$MAIN_ROOT" symbolic-ref --quiet refs/remotes/origin/HEAD || true)
fi
BASE_REF=${ORIGIN_HEAD#refs/remotes/}
[ -z "$BASE_REF" ] && BASE_REF=HEAD

if [ -e "$DEST" ]; then
  echo "Worktree path already exists: $DEST" >&2
  exit 1
fi

mkdir -p "$(dirname "$DEST")"
if [ -d "$HOME/Code/mono" ] && [ ! -e "$HOME/Code/worktrees/mono" ]; then
  ln -s "$HOME/Code/mono" "$HOME/Code/worktrees/mono"
fi

# New branch named after the requested name; if it already exists, check it out instead.
if git -C "$MAIN_ROOT" show-ref --verify --quiet "refs/heads/$NAME"; then
  git -C "$MAIN_ROOT" worktree add "$DEST" "$NAME" >&2
else
  git -C "$MAIN_ROOT" worktree add -b "$NAME" "$DEST" "$BASE_REF" >&2
fi

echo "$DEST"
