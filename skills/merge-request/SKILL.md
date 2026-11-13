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
3. Check whether the branch serves one goal. Several concerns that serve that goal belong in one MR/PR, kept apart by commits. Propose a split only when a concern serves a different goal, or when its size or risk would make one review hard to complete; stack the MRs when they depend on each other.
4. Draft the title and description from the actual commits and diff, writing the description to `mr-description.md` in the scratchpad or another directory outside the repository. Do not rely on the branch name alone.
5. Preserve project template headings when present; otherwise use the format below.
6. Reconcile the final diff and draft with the user's requested outcomes and exclusions. Use reconciliation as an internal completeness check; publish only information a reviewer needs. Run the change-writing Review Pass, then present the title and description for approval before creating or updating, unless the user explicitly asked to submit without review.
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

Write the opening line only for a stack, or for a ticket the user named for this MR. Use one section per reviewer decision. Treat implementation structure only as navigation. Headings are statements a reviewer could disagree with, not topics.

Add only when present:

```markdown
## <What the checks showed, e.g. "Replaying last week's webhooks charges each order once">

- Manual verification or checks CI does not run, without test counts.

## <The measured result, e.g. "Request time drops from 350 ms to 40 ms">

| Metric | Before | After | Method |
| --- | ---: | ---: | --- |
| ... | ... | ... | ... |
```

## Writing Rules

- Include only context needed to evaluate a decision: the problem and its evidence, caller-visible behaviour, the reason for the approach, effects outside the repository, and checks CI does not run. Contracts, tests, and the diff own the complete behavioural specification.
- Delete a sentence when removing it would not change a review decision, deployment order, compatibility concern, or known risk.
- Keep the title specific to the reviewer-visible change.
- Make the first section readable by anyone who might open the MR, not only the assigned reviewer.
- Spend the most words on decisions that are expensive to undo after merge: data shape, protocols, dependencies, permissions, security controls. Skip choices a follow-up of a few hours could change.
- State a hard-to-undo consequence, a deploy dependency, or expected work left out in one sentence where it applies.
- Treat a heading as a context reset: name the subject in the first sentence or bullet instead of starting with `it`, `this`, or `they`.
- For UI changes, add a screenshot where the change is obvious without zooming, or a GIF under 15 seconds.
- For migrations, background jobs, permissions, and data shape changes, state what the diff hides: lock or run time, deploy order, rows left in the old shape, and callers that see different behaviour.
- Link references inline where the text cites them.
- Wrap values written as `YYYY-MM` or `YYYY-MM-DD`, such as API version `2026-10-21`, in inline code; GitLab otherwise links the `2026-10` prefix as an external issue. Write calendar dates in prose as 21 October 2026.
- For upgraded dependencies, state each version change as `name old → new` and link its changelog or release/compare page.
- Do not list the MR's commits.
- Do not paste long changelog excerpts when a link and short summary are enough.
- Do not include names or sensitive details from private threads unless the user asks.
- Put each sentence's subject and verb within its first few words, and rewrite noun stacks such as `retry handling configuration` as a verb phrase.
