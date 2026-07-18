#!/usr/bin/env bash
# Mirrors the Hydro fish prompt: dim path with bold last segment,
# git branch + dirty/ahead/behind markers, active model.

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name')

# Context %: always present. 5h quota: Pro/Max only, after first API response.
ctx_used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
rl5_used=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
rl5_resets=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
now=$(date +%s)

home="$HOME"
display_path="$cwd"
case "$display_path" in
  "$home") display_path="~" ;;
  "$home"/*) display_path="~${display_path#"$home"}" ;;
esac

parent="${display_path%/*}"
last="${display_path##*/}"
if [ "$parent" = "$display_path" ]; then
  parent=""
fi

DIM="\033[2m"
BOLD="\033[1m"
RESET="\033[0m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"

if [ -n "$parent" ] && [ "$parent" != "$last" ]; then
  path_out="${DIM}${parent}/${RESET}${BOLD}${last}${RESET}"
else
  path_out="${BOLD}${last}${RESET}"
fi

git_out=""
if git -C "$cwd" --no-optional-locks rev-parse --show-toplevel >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null \
    || git -C "$cwd" --no-optional-locks describe --tags --exact-match HEAD 2>/dev/null \
    || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null | sed 's/^/@/')

  dirty=""
  if ! git -C "$cwd" --no-optional-locks diff-index --quiet HEAD 2>/dev/null \
    || [ -n "$(git -C "$cwd" --no-optional-locks ls-files --others --exclude-standard)" ]; then
    dirty=" •"
  fi

  upstream=""
  counts=$(git -C "$cwd" --no-optional-locks rev-list --count --left-right '@{upstream}...@' 2>/dev/null)
  if [ -n "$counts" ]; then
    behind=$(echo "$counts" | cut -f1)
    ahead=$(echo "$counts" | cut -f2)
    if [ "$ahead" != "0" ] && [ "$behind" != "0" ]; then
      upstream=" ↑${ahead} ↓${behind}"
    elif [ "$ahead" != "0" ]; then
      upstream=" ↑${ahead}"
    elif [ "$behind" != "0" ]; then
      upstream=" ↓${behind}"
    fi
  fi

  git_out=" ${branch}${dirty}${upstream}"
fi

# Right-side usage indicators, thresholds mirroring the reference statusline.
usage_color() {
  if   [ "$1" -ge 80 ]; then printf '%s' "$RED"
  elif [ "$1" -ge 50 ]; then printf '%s' "$YELLOW"
  else                       printf '%s' "$GREEN"; fi
}

# Model, context and usage, joined by a dimmed dot.
sep="${DIM} · ${RESET}"
tail="${DIM}${model}${RESET}"
if [ -n "$ctx_used" ]; then
  ctx_pct=$(printf '%.0f' "$ctx_used")
  tail="${tail}${sep}${DIM}ctx${RESET} $(usage_color "$ctx_pct")${ctx_pct}%${RESET}"
fi
if [ -n "$rl5_used" ]; then
  rl5_pct=$(printf '%.0f' "$rl5_used")
  tail="${tail}${sep}${DIM}5h${RESET} $(usage_color "$rl5_pct")${rl5_pct}%${RESET}"
  if [ -n "$rl5_resets" ] && [ "$rl5_resets" -gt "$now" ] 2>/dev/null; then
    mins=$(( (rl5_resets - now) / 60 ))
    if [ "$mins" -ge 60 ]; then reset_fmt="$(( mins / 60 ))h$(( mins % 60 ))m"; else reset_fmt="${mins}m"; fi
    tail="${tail} ${DIM}${reset_fmt}${RESET}"
  fi
fi

printf "%b%b %b" "$path_out" "$git_out" "$tail"
