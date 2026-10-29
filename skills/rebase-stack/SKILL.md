---
name: rebase-stack
description: Rebase one MR or a stack of dependent MRs onto their targets and push them. Use when asked to rebase an MR, rebase on main, rebase a chain, stack, or train, restack, or check whether MRs are stacked correctly.
---

# Rebase Stack

A stack is a chain of MRs where each MR targets the branch of the one before it; the first targets the stack's base branch, usually `main`.

## Procedure

1. Resolve the stack: for each MR, read its source and target branch with `glab mr view <iid> -F json`. Follow target branches inward until the target has no MR in the stack; that target is the base branch. Follow source branches outwards from there.
2. Show the chain as `<base> ← A ← B ← C`. Flag any MR whose target does not match the previous MR's source branch, and fix the target only when the user confirms.
3. `git fetch origin`, then for each MR in order, in its worktree:
   - `git rebase origin/<target>`
   - resolve conflicts; stop and report when a conflict needs a decision
   - on a `db/schema.rb` conflict limited to the `define(version:)` line, keep the newer version; do not run `db:prepare` or `db:migrate` to regenerate it, because the local Rails version can rewrite the dump
   - `git push --force-with-lease=<branch>:origin/<branch> origin <branch>`
4. For each MR, check that the description still matches the rebased diff (merge-request skill, step 8).
