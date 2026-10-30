INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')
CWD=$(echo "$INPUT" | jq -r '.cwd')
SESSION=$(echo "$INPUT" | jq -r '.session_id')

if ! echo "$COMMAND" | grep -qE '(^|[&|;(][[:space:]]*)devenv([[:space:]]+[^&|;[:space:]]+)*[[:space:]]+up([[:space:]]|$)'; then
  exit 0
fi

ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null) || exit 0

case "$ROOT" in
  "$HOME"/Code/worktrees/*) ;;
  *) exit 0 ;;
esac

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/claude-code/devenv-up"
mkdir -p "$STATE_DIR"
grep -qxF "$ROOT" "$STATE_DIR/$SESSION" 2>/dev/null || printf '%s\n' "$ROOT" >>"$STATE_DIR/$SESSION"
