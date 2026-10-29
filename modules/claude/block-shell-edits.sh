INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

block() {
  echo "BLOCKED: '$COMMAND' edits files through an in-place shell command. Use Edit for existing files or Write for new files and complete rewrites." >&2
  exit 2
}

if echo "$COMMAND" | grep -qE '(^|[&|;(][[:space:]]*)sed([[:space:]]+[^&|;]*)?[[:space:]]+(--in-place(=[^[:space:]]*)?|-i([^[:space:]]*)?)([[:space:]]|$)'; then
  block
fi

if echo "$COMMAND" | grep -qE '(^|[&|;(][[:space:]]*)perl([[:space:]]+[^&|;]*)?[[:space:]]+-[0-9A-Za-z]*i[0-9A-Za-z]*([[:space:]]|$)'; then
  block
fi

exit 0
