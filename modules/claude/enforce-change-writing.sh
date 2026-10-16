INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty')

MR_PATTERN='(^|[[:space:]&|;(])(glab[[:space:]]+mr[[:space:]]+(create|edit|update)|gh[[:space:]]+pr[[:space:]]+(create|edit))([[:space:]&|;)]|$)'
COMMIT_PATTERN='(^|[[:space:]&|;(])git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+commit([[:space:]]|$)'

writes_prose() {
  if echo "$COMMAND" | grep -qE "$MR_PATTERN"; then
    return 0
  fi
  if echo "$COMMAND" | grep -qE "$COMMIT_PATTERN" && ! echo "$COMMAND" | grep -qE -- '--no-edit|--fixup'; then
    return 0
  fi
  # MR descriptions are often published from a script that reads them from a file.
  while read -r script; do
    case "$script" in
      /*) path=$script ;;
      \~/*) path="$HOME/${script#\~/}" ;;
      *) path="${CWD:-.}/$script" ;;
    esac
    if [ -f "$path" ] && grep -qE "$MR_PATTERN" "$path"; then
      return 0
    fi
  done < <(echo "$COMMAND" | grep -oE '[^[:space:]"'\'';|&()]+\.sh' || true)
  return 1
}

if ! writes_prose; then
  exit 0
fi

# The skill body reaches the transcript only when the skill was actually read.
if [ -n "$TRANSCRIPT" ] && grep -qF '# Change Writing' "$TRANSCRIPT"; then
  exit 0
fi

echo "BLOCKED: commit messages and MR/PR descriptions require reading and applying change-writing/SKILL.md first." >&2
exit 2
