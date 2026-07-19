# Agent instructions

- Keep comments rare and concise; add one only when the why isn't obvious from the code — a hidden constraint, a subtle invariant, or a workaround for a specific case.
- When no sharper rule applies, match the surrounding code — its formatting, naming, layout, and test structure. This governs how you write, not whether to add explanatory prose; comment density follows the rule above.
- Pick the API whose behavior doesn't exceed what your tests constrain; extra capability is behavior no test pins down — the kind mutation testing surfaces as surviving mutants.
- Keep config files free of keys whose value equals the tool's built-in default, unless the key is there to pin a value against an upstream change — note that intent in the commit.
- Look in git history and commit messages for past rationale, and record current rationale there rather than in comments.
- When upgrading a dependency, reference its changelog for the traversed version range in the commit message: link it by URL rather than pasting its contents; if there's no changelog, link the release or compare view for the range.
- Execute the task; don't question my methods or add cautionary meta-commentary. Warn only when you can name what breaks and under what condition — once, then stop.
- Avoid jargon when explaining how things work; prefer plain language, and specifically avoid the words "load-bearing" and "genuinely".
- When showing a benchmark result, present the numbers in a table — before and after when there's a baseline — and state how each number was measured and what assumptions it rests on.
