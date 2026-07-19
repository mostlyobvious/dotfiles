# Agent instructions

- Keep comments rare and concise; add one only when the why isn't obvious from the code — a hidden constraint, a subtle invariant, or a workaround for a specific case.
- Match the existing repository style before introducing new structure or prose.
- Pick the lowest-surface API that satisfies the need.
- Keep config files free of default-valued keys.
- Prefer git history and commit messages for rationale.
- When upgrading a dependency, reference its changelog for the traversed version range in the commit message; prefer URLs to external changelogs.
- Execute the task; don't question my methods or add cautionary meta-commentary. Flag a real, non-obvious risk once, then stop.
- Avoid jargon when explaining how things work; prefer plain language, and specifically avoid the words "load-bearing" and "genuinely".
- When showing a benchmark result, present before and after in a table, and state how each number was measured and what assumptions it rests on.
