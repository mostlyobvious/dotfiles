# Runs under writeShellApplication (set -euo pipefail). The reader gets the
# description alone: no session, no diff, no tools, no CLAUDE.md.
if [ "$#" -ne 1 ]; then
  echo "usage: mr-cold-read <file>" >&2
  exit 64
fi

file=$1

if [ ! -s "$file" ]; then
  echo "mr-cold-read: $file is missing or empty" >&2
  exit 1
fi

prompt='You are the reviewer who receives this merge request description. You know the codebase in general and its common tools. You have not seen the diff, the branch, or any of the work behind it, and you have ten minutes.

Report three lists, tersely. Quote the first six words of each sentence or table row you name. Leave a list empty when nothing in the text earns a place on it; a tight description has three empty lists.

CUT: sentences and table rows you could delete without losing what you need to decide whether to approve, or what an operator needs to act. Detail the diff shows, how the author checked something, a fact stated twice, and background a reviewer of this codebase already has all count.

HISTORY: phrases that point at the work of the author, not at the change: an earlier run, a saved file, a comparison made on some date, a step tried and dropped. Say what the reader cannot know.

UNCLEAR: passages you read twice or could not follow. Say in one line what you could not tell, such as which side is wrong, what a number is counted over, or whether something is asked of you.

Then one line: KEEP <n> of <total> sentences.
Then two sentences: the problem this merge request solves and what it changes, from the text alone. A summary the author would not recognise tells them the opening fails.

Do not rewrite the description.'

claude -p --model sonnet --tools "" --no-session-persistence \
  --disable-slash-commands --setting-sources "" \
  --system-prompt "$prompt" <"$file"
