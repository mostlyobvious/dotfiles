#!/usr/bin/env bash
# Stop hook: run the quality gate. On failure, exit 2 so Claude Code blocks the
# stop and hands the output back to the agent to fix; on success, exit 0 to let
# the turn end. It keeps retrying until green — interrupt to break out, or guard
# on the input's stop_hook_active to cap it at one attempt.
set -uo pipefail

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

if ! output=$(make check 2>&1); then
  printf '%s\n' "$output" >&2
  exit 2
fi
