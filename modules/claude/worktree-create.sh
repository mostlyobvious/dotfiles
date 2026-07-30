# Runs under writeShellApplication (set -euo pipefail). Claude Code's
# WorktreeCreate hook: it fully replaces the default `git worktree add`, so this
# script both places the worktree under ~/Code/worktrees/<repo>/<name> and copies
# local, gitignored config into it. The created path MUST be the last stdout
# line; all other output goes to stderr; any non-zero exit aborts creation.

INPUT=$(cat)
NAME=$(echo "$INPUT" | jq -r '.name')
CWD=$(echo "$INPUT" | jq -r '.cwd')

# The repo's primary working tree — our copy source and the basis for <repo> —
# regardless of whether Claude runs from a linked worktree.
COMMON_DIR=$(git -C "$CWD" rev-parse --path-format=absolute --git-common-dir)
MAIN_ROOT=$(dirname "$COMMON_DIR")
REPO=$(basename "$MAIN_ROOT")

DEST="$HOME/Code/worktrees/$REPO/$NAME"

# Base ref: origin's default branch (fresh). Fall back to HEAD if there's no origin.
ORIGIN_HEAD=$(git -C "$MAIN_ROOT" symbolic-ref --quiet refs/remotes/origin/HEAD || true)
if [ -z "$ORIGIN_HEAD" ]; then
  git -C "$MAIN_ROOT" remote set-head origin --auto >&2 || true
  ORIGIN_HEAD=$(git -C "$MAIN_ROOT" symbolic-ref --quiet refs/remotes/origin/HEAD || true)
fi
BASE_REF=${ORIGIN_HEAD#refs/remotes/}
[ -z "$BASE_REF" ] && BASE_REF=HEAD

mkdir -p "$(dirname "$DEST")"

# New branch named after the slug; if it already exists, check it out instead.
if git -C "$MAIN_ROOT" show-ref --verify --quiet "refs/heads/$NAME"; then
  git -C "$MAIN_ROOT" worktree add "$DEST" "$NAME" >&2
else
  git -C "$MAIN_ROOT" worktree add -b "$NAME" "$DEST" "$BASE_REF" >&2
fi

# Carry uncommitted local config from the main checkout, if present.
CARRY=(
  devenv.nix devenv.yaml devenv.lock devenv.local.nix
  .envrc .env .mcp.json
  .claude/settings.json .claude/settings.local.json .claude/hooks
)
for item in "${CARRY[@]}"; do
  src="$MAIN_ROOT/$item"
  if [ -e "$src" ]; then
    mkdir -p "$(dirname "$DEST/$item")"
    cp -R "$src" "$DEST/$item" >&2
  fi
done

echo "$DEST"
