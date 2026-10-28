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
3. Check whether the branch is one logical review unit. If it mixes unrelated concerns, propose a split before opening the MR/PR: one MR per concern, stacked on each other when they depend on each other.
4. Draft the title and description from the actual commits and diff, writing the description to a file named `mr-description.md`. Do not rely on the branch name alone.
5. Preserve project template headings when present; otherwise use the format below.
6. Run the change-writing Review Pass on the draft, then present the title and description for approval before creating or updating, unless the user explicitly asked to submit without review.
7. When opening a GitLab MR, explicitly set squash-on-merge to false and verify it after creation.
8. After pushing to a branch with an open MR, compare its description against the new diff and propose an update when they disagree.

## Default Description Format

```markdown
Linear: BE-123. Stacked on !6943; review that first.

## <Finding: what was broken, slow, or missing>

- The problem and its evidence, with a before/after when behaviour changes.

## <Why this approach>

- Choices the diff doesn't explain, effects outside the repository,
  and expected work left out. Only what applies.
```

Write the opening line only when there is a ticket or a stack. Headings state the finding, as in "What was slow" or "No backfill", not a topic.

Add only when present:

```markdown
## Verification

- Manual verification or checks CI does not run, without test counts.

## Benchmarks

| Metric | Before | After | Method |
| --- | ---: | ---: | --- |
| ... | ... | ... | ... |
```

## Writing Rules

- Describe only what the diff can't show: the problem and its evidence, behaviour seen from the caller's side, the reason for the approach, effects outside the repository, and checks CI doesn't run. Name a file or method only to point the reviewer at a decision in it.
- Keep the title specific to the reviewer-visible change.
- Make the first section readable by anyone who might open the MR, not only the assigned reviewer.
- Spend the most words on decisions that are expensive to undo after merge: data shape, protocols, dependencies, permissions, security controls. Skip choices a follow-up of a few hours could change.
- State a hard-to-undo consequence or a deploy dependency in one sentence where it applies; skip reversible or easy-to-change decisions.
- The headings plus the first bullet of each section should tell the whole change to someone skimming.
- For UI changes, add a screenshot where the change is obvious without zooming, or a GIF under 15 seconds.
- Keep descriptions concise; skip filler and dramatic framing.
- Mention migrations, background jobs, operational changes, permissions, data shape changes, and compatibility behavior when present.
- Link references inline where the text cites them.
- For upgraded dependencies, state each version change as `name old → new` and link its changelog or release/compare page.
- Mention work outside this MR only when a reviewer would otherwise expect it here. Do not list the MR's commits.
- Do not paste long changelog excerpts when a link and short summary are enough.
- Do not include names or sensitive details from private threads unless the user asks.
