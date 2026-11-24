---
name: merge-request
description: Prepare, open, or update a merge request or pull request. Use when asked to submit, ship, draft, open, create, or revise an MR/PR description or title.
---

# Merge Request

An MR description shares knowledge: it tells a reviewer from outside the work why the change exists and what it changes. Four primary rules govern every MR, small or mechanical ones included. Every other rule in this skill is secondary and yields when it conflicts with them.

## Primary Rules

1. Lead with the why. Open the description with one plain sentence naming the problem the MR solves, such as "The problem we're solving is that we can't correlate sweep runs." The why lives with the people who chose the work, so take it only from words a person wrote: the user's messages in this session, or a ticket or thread a person wrote. Your own earlier messages, commit messages you wrote, agent-written tickets, the diff, generated artifacts, slides, and notes do not count.
2. Write for an outsider. The reviewer usually works outside this area and has seen none of the work. Define a domain term at first use when a claim in the description depends on it. State each finding as a fact the reviewer could re-check today, and leave out how, when, or from which local file you found it.
3. Keep the problem apart from the change. The problem section describes how things stand before the MR; the change section describes what the MR does. Every bullet must read unambiguously as one or the other.
4. Stay inside the budget: 300 words of prose, 12 list items, 5 sections, 40 words per list item. Code blocks and tables sit outside the word count, and the linter enforces all four. The budget is a ceiling: most MRs need two sections and a third of it. Spend it on the problem, the outcome, and what the reviewer cannot see in the diff; the diff, the tests, and the commits already carry the rest.

## Procedure

1. Read `../change-writing/SKILL.md`.
2. Inspect state:
   - `git status`
   - current branch and target branch
   - commits included in the branch
   - diff against the target branch
   - project MR/PR template, if present
3. Find the why in a source primary rule 1 accepts, and quote it word for word. When no such source states it, or you cannot tell who wrote a source, ask the user for the why. The step is done when you hold a verbatim quote and its source.
4. Check whether the branch serves one goal. Several concerns that serve that goal belong in one MR/PR, kept apart by commits. Propose a split only when a concern serves a different goal, or when its size or risk would make one review hard to complete; stack the MRs when they depend on each other.
5. Draft the title and description from the why, the actual commits, and the diff, writing the description to `mr-description.md` in the scratchpad or another directory outside the repository. Do not rely on the branch name alone.
6. Preserve project template headings when present, and place the why sentence and problem section before them; otherwise use the format below.
7. Check the draft against each primary rule, then reconcile the final diff and draft with the user's requested outcomes and exclusions. Run the change-writing Review Pass.
8. Run `mr-cold-read <file>`. A reader who sees only the description lists what to cut, what points at your work instead of the change, and what it could not follow, then summarises the MR in two sentences. Apply every finding you agree with and rerun after each edit; publishing is blocked until the reader has read the current text. The step is done when a run returns no finding you would act on and its summary matches the why.
9. Present the title, the description, the why quote with its source, and any reader finding you left unapplied, for approval before creating or updating, unless the user explicitly asked to submit without review.
10. When opening a GitLab MR, explicitly set squash-on-merge to false and verify it after creation.
11. After pushing to a branch with an open MR, compare its description against the new diff and propose an update when they disagree.

## Default Description Format

```markdown
The problem we're solving is that <the why, in one sentence>.

## <How things stand before this MR, e.g. "Sweep findings live only in Argo run logs">

- The evidence, in terms an outsider follows.

## <What this MR changes, e.g. "Each sweep finding is stored with its run ID">

- What a reader can do after the MR that they could not before, with a before/after when behaviour changes.
```

Headings are statements a reviewer could disagree with, not topics.

Add a section below only when the reviewer must decide or act on it, up to the budget's five in all:

```markdown
## <A decision as a statement, e.g. "Rows written before this keep their metadata">

- Choices the diff doesn't explain and effects outside the repository.

## <What the checks showed, e.g. "Replaying last week's webhooks charges each order once">

- Manual verification or checks CI does not run.

## <The measured result, e.g. "Request time drops from 350 ms to 40 ms">

| Metric | Before | After | Method |
| --- | ---: | ---: | --- |
| ... | ... | ... | ... |
```

Use one decision section per reviewer decision. Treat implementation structure only as navigation.

## Secondary Rules

- When the user named a Linear issue for this MR, start the title with its ID and a space, as in `BE-926 Add organization instructions to new agent chats`. Leave the ID out otherwise.
- Delete each sentence an outsider would not miss. What survives is caller-visible behaviour, the reason for the approach, effects outside the repository, deployment order, compatibility concerns, and known risks, each only when this MR has one.
- Finish the evidence before drafting. An unexplained difference, an empty table cell, or one side of a comparison left unmeasured is a check to run, then a fact to state.
- Show a number that differs as the numbers side by side, then give the cause in one sentence.
- Spend the most words on decisions that are expensive to undo after merge: data shape, protocols, dependencies, permissions, security controls. Skip choices a follow-up of a few hours could change.
- Treat a heading as a context reset: name the subject in the first sentence or bullet instead of starting with `it`, `this`, or `they`.
- For UI changes, add a screenshot where the change is obvious without zooming, or a GIF under 15 seconds.
- For migrations, background jobs, permissions, and data shape changes, state what the diff hides: lock or run time, deploy order, rows left in the old shape, and callers that see different behaviour.
- Link references inline where the text cites them.
- Wrap values written as `YYYY-MM` or `YYYY-MM-DD`, such as API version `2026-10-21`, in inline code; GitLab otherwise links the `2026-10` prefix as an external issue. Write calendar dates in prose as 21 October 2026.
- For upgraded dependencies, state each version change as `name old → new`.
- Do not list the MR's commits.
- Do not paste long changelog excerpts when a link and short summary are enough.
