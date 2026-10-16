---
name: rebase-stack
description: Rebase one MR or a stack of dependent MRs onto their targets and push them. Use when asked to rebase an MR, rebase on main, rebase a chain, stack, or train, restack, or check whether MRs are stacked correctly.
---

# Rebase Stack

A stack is a chain of MRs where each MR targets the branch of the one before it; the first targets `main`.

## Procedure

1. Resolve the stack: for each MR, read its source and target branch with `glab mr view <iid> -F json`. Order the chain from the MR that targets `main` outwards.
2. Show the chain as `main ← A ← B ← C`. Flag any MR whose target does not match the previous MR's source branch, and fix the target only when the user confirms.
3. `git fetch origin`, then for each MR in order, in its worktree:
   - `git rebase origin/<target>`
   - resolve conflicts with the resolving-merge-conflicts skill; stop and report when a conflict needs a decision
   - `git push --force-with-lease=<branch>:origin/<branch> origin <branch>`
4. Push one branch at a time and wait for its pipeline to start before the next; parallel pushes exhaust shared build capacity.
5. After all pushes, list each MR with its pipeline status and URL. Read the failing job of any red pipeline before proposing a fix.
6. For each MR, check that the description still matches the rebased diff (merge-request skill, step 8).
