#!/usr/bin/env bash
# Mirrors the Hydro fish prompt: dim path with bold last segment,
# git branch + dirty/ahead/behind markers, active model.

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name')

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

  git_out=" ${DIM}\$${RESET}${branch}${dirty}${upstream}"
fi

printf "%b%b ${DIM}[%s]${RESET}" "$path_out" "$git_out" "$model"
