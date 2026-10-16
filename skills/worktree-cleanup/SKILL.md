---
name: worktree-cleanup
description: Remove worktrees and local branches whose MRs are merged or closed. Use when asked to drop, prune, or clean up merged, closed, stale, or leftover worktrees and branches.
---

# Worktree Cleanup

Worktrees live under `~/Code/worktrees/<repo>/<name>`; each belongs to a main checkout found through `git rev-parse --git-common-dir`.

## Procedure

1. List every worktree under `~/Code/worktrees` with its main checkout, branch, and `git status --porcelain`.
2. For each branch, look up its MR with `glab mr list --all --source-branch <branch> -F json`, run from the main checkout and record the state: opened, merged, closed, or none.
3. Show a table of what goes and what stays:

   | Repo | Worktree | Branch | MR | State | Dirty |
   | --- | --- | --- | --- | --- | --- |

4. Remove without asking when the MR is merged or closed and the worktree is clean. Ask about dirty worktrees, branches with no MR, and anything the user did not name.
5. For each removal, from the main checkout:
   - run `devenv down` in the worktree when it has devenv processes running
   - `git worktree remove <path>`, adding `--force` only for a dirty worktree the user approved
   - `git branch -D <branch>`
6. Run `git worktree prune` in each main checkout touched.
7. Report what was removed and what was kept, with the reason for each kept item.
