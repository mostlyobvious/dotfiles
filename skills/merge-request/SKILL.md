---
name: merge-request
description: Prepare, open, or update a merge request or pull request. Use when asked to submit, ship, draft, open, create, review, or revise an MR/PR description or title.
---

# Merge Request

Before drafting the title or description, read and apply `../change-writing/SKILL.md`.

## Procedure

1. Read `../change-writing/SKILL.md`.
2. Inspect state:
   - `git status`
   - current branch and target branch
   - commits included in the branch
   - diff against the target branch
   - project MR/PR template, if present
3. Check whether the branch is one logical review unit. If it mixes unrelated concerns, propose a split before opening the MR/PR.
4. Draft the title and description from the actual commits and diff. Do not rely on the branch name alone.
5. Preserve project template headings when present; otherwise use the format below.
6. Present the title and description for approval before creating or updating, unless the user explicitly asked to submit without review.
7. When opening a GitLab MR, explicitly set squash-on-merge to false and verify it after creation.

## Default Description Format

```markdown
## Summary

- ...

## Why

- ...

## Verification

- Manual verification or checks CI does not run, without test counts.
```

Add only sections that matter:

```markdown
## Risk

- ...

## Rollout

- ...

## Benchmarks

| Metric | Before | After | Method |
| --- | ---: | ---: | --- |
| ... | ... | ... | ... |

## References

- ...
```

## Writing Rules

- Keep the title specific to the reviewer-visible change.
- Put the reviewer-critical context near the top.
- Make the Summary readable by anyone who might open the MR, not only the assigned reviewer.
- Spend the most words on decisions that are expensive to undo after merge: data shape, protocols, dependencies, permissions, security controls. Skip choices a follow-up of a few hours could change.
- Add Risk only for material consequences that are hard to reverse or change; omit reversible or easy-to-change decisions.
- The headings plus the first bullet of each section should tell the whole change to someone skimming.
- For UI changes, add a screenshot where the change is obvious without zooming, or a GIF under 15 seconds.
- Keep descriptions concise; skip filler, dramatic framing, and details obvious from the diff.
- Mention migrations, background jobs, operational changes, permissions, data shape changes, and compatibility behavior when present.
- Link dependency changelogs or release/compare pages for upgraded dependencies.
- Do not paste long changelog excerpts when a link and short summary are enough.
- Do not include names or sensitive details from private threads unless the user asks.
