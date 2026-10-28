---
name: merge-stack
description: Queue a stack of GitLab merge requests on a merge train in dependency order. Use when asked to merge a stack, merge a train, or enqueue stacked MRs.
---

# Merge Stack

Queue the whole stack and stop.

## Procedure

1. Resolve the open stack from the given MR. Follow target branches towards `main` and source branches away from it.
2. Show the chain as `main ← !A ← !B ← !C`.
3. Read the project settings with `glab api projects/:id`. When `merge_pipelines_enabled` or `merge_trains_enabled` is false, stop and give this command:

   ```bash
   glab api --method PUT projects/:id \
     -F merge_pipelines_enabled=true \
     -F merge_trains_enabled=true
   ```

4. Retarget every open MR in the chain to `main`.
5. In dependency order, read each MR's current SHA and enqueue it with:

   ```bash
   glab mr merge <iid> --sha <sha> --squash=false --auto-merge --remove-source-branch --yes
   ```

   Continue when an already-green MR merges immediately.
6. Report each MR as merged or queued. The task ends after the enqueue calls; leave pipelines, deployments, and production checks to GitLab and the user.
