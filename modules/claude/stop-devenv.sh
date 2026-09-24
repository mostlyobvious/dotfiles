INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // env.PWD')

case "$CWD" in
  "$HOME"/Code/worktrees/*) ;;
  *) exit 0 ;;
esac

ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$CWD")

case "$ROOT" in
  "$HOME"/Code/worktrees/*) ;;
  *) exit 0 ;;
esac

if [ ! -f "$ROOT/devenv.nix" ] && [ ! -f "$ROOT/devenv.yaml" ] && [ ! -d "$ROOT/.devenv" ]; then
  exit 0
fi

cd "$ROOT"

if ! devenv down >/dev/null 2>&1; then
  echo "Failed to stop devenv processes for $ROOT" >&2
fi
