---
name: rebase-stack
description: Rebase and push a stack of dependent GitLab merge requests in dependency order. Use when asked to rebase, restack, or update a stack on its base branch.
---

# Rebase Stack

Rebase the whole stack and stop.

## Procedure

1. Resolve the open stack from the given MR. Follow target branches towards `main` and source branches away from it.
2. Show the chain as `main ← !A ← !B ← !C`. Stop when the targets do not form one chain.
3. Fetch `origin`.
4. In dependency order, find or create a clean worktree for each branch, then:
   - record the current remote SHA
   - rebase onto the updated target branch
   - push with `--force-with-lease=<branch>:<recorded-sha>`
5. Stop and report a rebase conflict that needs a decision. Leave the rebase in progress.
6. Report each rebased branch. The task ends after the pushes; leave pipelines and merge request descriptions alone.
