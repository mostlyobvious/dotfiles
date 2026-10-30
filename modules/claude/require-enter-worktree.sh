INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')
CWD=$(echo "$INPUT" | jq -r '.cwd')
WORKTREES="$HOME/Code/worktrees"

if echo "$COMMAND" | grep -qE '(^|[&|;(][[:space:]]*)git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+worktree[[:space:]]+add([[:space:]]|$)'; then
  echo "BLOCKED: create worktrees with EnterWorktree (name), which runs the WorktreeCreate hook and moves this session into the new worktree." >&2
  exit 2
fi

NORMALIZED=${COMMAND//\$HOME/$HOME}
NORMALIZED=${NORMALIZED//\~\//$HOME/}
TARGET=$(echo "$NORMALIZED" | grep -oE "(^|[&|;(][[:space:]]*)cd[[:space:]]+[\"']?$WORKTREES/[^/[:space:]\"';&|)]+/[^/[:space:]\"';&|)]+" | head -n 1 | grep -oE "$WORKTREES/.*" || true)

if [ -z "$TARGET" ]; then
  exit 0
fi

case "$CWD/" in
  "$TARGET"/*) exit 0 ;;
esac

echo "BLOCKED: this session runs in $CWD. Call EnterWorktree with path $TARGET so every command starts there, then rerun without the cd." >&2
exit 2
