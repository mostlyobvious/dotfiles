INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

if ! echo "$COMMAND" | grep -qE '(^|[[:space:]&|;(])git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+commit([[:space:]]|$)'; then
  exit 0
fi

if ! echo "$COMMAND" | grep -qiE 'co-authored-by:.*(anthropic|claude)|((anthropic|claude).*)co-authored-by:'; then
  exit 0
fi

echo "BLOCKED: commit messages must not include Anthropic or Claude co-author attribution." >&2
exit 2
