---
name: merge-request
description: Prepare, open, or update a merge request or pull request. Use when asked to submit, ship, draft, open, create, review, or revise an MR/PR description or title.
---

# Merge Request

## Procedure

1. Read `../change-writing/SKILL.md`.
2. Inspect state:
   - `git status`
   - current branch and target branch
   - commits included in the branch
   - diff against the target branch
   - project MR/PR template, if present
3. Check whether the branch is one logical review unit. If it mixes unrelated concerns, propose a split before opening the MR/PR: one MR per concern, stacked on each other when they depend on each other.
4. Draft the title and description from the actual commits and diff, writing the description to `mr-description.md` in the scratchpad or another directory outside the repository. Do not rely on the branch name alone.
5. Preserve project template headings when present; otherwise use the format below.
6. Run the change-writing Review Pass on the draft, then present the title and description for approval before creating or updating, unless the user explicitly asked to submit without review.
7. When opening a GitLab MR, explicitly set squash-on-merge to false and verify it after creation.
8. After pushing to a branch with an open MR, compare its description against the new diff and propose an update when they disagree.

## Default Description Format

```markdown
Linear: BE-123. Stacked on !6943; review that first.

## <The problem as a statement, e.g. "Serializers spend 330 ms of a 350 ms request">

- The evidence, with a before/after when behaviour changes.

## <The decision as a statement, e.g. "Rows written before this keep their metadata">

- Choices the diff doesn't explain and effects outside the repository.
```

Write the opening line only for a stack, or for a ticket the user named for this MR. Headings are statements a reviewer could disagree with, not topics.

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
- State a hard-to-undo consequence, a deploy dependency, or expected work left out in one sentence where it applies.
- The headings plus the first bullet of each section should tell the whole change to someone skimming.
- For UI changes, add a screenshot where the change is obvious without zooming, or a GIF under 15 seconds.
- Keep descriptions concise; skip filler and dramatic framing.
- For migrations, background jobs, permissions, and data shape changes, state what the diff hides: lock or run time, deploy order, rows left in the old shape, and callers that see different behaviour.
- Link references inline where the text cites them.
- For upgraded dependencies, state each version change as `name old → new` and link its changelog or release/compare page.
- Do not list the MR's commits.
- Do not paste long changelog excerpts when a link and short summary are enough.
- Do not include names or sensitive details from private threads unless the user asks.
