---
name: merge-stack
description: Merge a stack or series of MRs one at a time, checking production between merges. Use when asked to merge a train or stack of MRs one by one, merge and monitor, or "rebase, merge, monitor".
---

# Merge Stack

Merge MRs in order, one at a time. Each merge deploys, and the next merge waits until the previous one has run in production without anomalies.

## Inputs

- The MRs, in merge order. When given only the first, follow the stack with the rebase-stack skill.
- The wait after each deploy. Default to 2 minutes when the user gives none.

## Procedure

For each MR:

1. Rebase it on its target with the rebase-stack skill when it is behind, and wait for a green pipeline.
2. Read its `sha` and `detailed_merge_status` with `glab api projects/:id/merge_requests/<iid>`. Continue only when the status is `mergeable`.
3. Merge with `glab mr merge <iid> --sha <sha> --squash=false --auto-merge=false --remove-source-branch --yes`. Without `--auto-merge=false`, glab only schedules the merge.
4. Wait for the `main` pipeline and the deploy to finish.
5. Wait the agreed time, then run the production-check skill for the window since the deploy.
6. Report one line per MR: merged, deployed, and the check verdict.
7. Continue to the next MR only when the check is healthy. On any anomaly, stop and report it with its evidence.

Retarget each following MR to `main` after its parent merges, if GitLab did not do it.
