INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty')

if ! echo "$COMMAND" | grep -qE '(^|[[:space:]&|;(])(glab[[:space:]]+mr[[:space:]]+(create|edit|update)|gh[[:space:]]+pr[[:space:]]+(create|edit))([[:space:]&|;)]|$)'; then
  exit 0
fi

if [ -n "$TRANSCRIPT" ] && grep -q 'change-writing/SKILL.md' "$TRANSCRIPT"; then
  exit 0
fi

echo "BLOCKED: MR/PR description changes require reading and applying change-writing/SKILL.md first." >&2
exit 2
