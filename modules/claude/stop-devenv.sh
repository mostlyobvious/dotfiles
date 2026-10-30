INPUT=$(cat)
SESSION=$(echo "$INPUT" | jq -r '.session_id')
STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/claude-code/devenv-up/$SESSION"

if [ ! -f "$STATE_FILE" ]; then
  exit 0
fi

while IFS= read -r ROOT; do
  [ -d "$ROOT" ] || continue
  if ! OUTPUT=$(cd "$ROOT" && devenv down 2>&1) && ! echo "$OUTPUT" | grep -q 'No process manager is running'; then
    echo "Failed to stop devenv processes for $ROOT" >&2
  fi
done <"$STATE_FILE"

rm -f "$STATE_FILE"
