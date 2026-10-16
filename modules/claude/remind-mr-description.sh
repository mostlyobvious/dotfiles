INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

if ! echo "$COMMAND" | grep -qE '(^|[[:space:]&|;(])git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+push([[:space:]]|$)'; then
  exit 0
fi

jq -n '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: "If the pushed branch has an open MR, compare its description with the new diff and propose an update when they disagree (merge-request skill, step 8)."
  }
}'
