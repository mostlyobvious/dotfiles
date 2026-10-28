INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ "$(basename "$FILE_PATH")" != "mr-description.md" ]; then
  exit 0
fi

jq -n '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: "Run the change-writing Review Pass on mr-description.md before presenting it for approval (merge-request skill, step 6)."
  }
}'
