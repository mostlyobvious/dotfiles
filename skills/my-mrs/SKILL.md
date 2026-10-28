---
name: my-mrs
description: List my open MRs with approval states, grouped by related work across repositories. Use when asked for my open MRs, approved MRs, MRs waiting for review, or an MR digest.
---

# My MRs

## Procedure

1. Fetch my open non-draft MRs across all projects: `glab api --paginate "merge_requests?scope=created_by_me&state=opened&wip=no&per_page=100"`. Drop `wip=no` when asked to include drafts.
2. Read approvals for every MR with `glab api projects/<project_id>/merge_requests/<iid>/approvals`. Include approved MRs and MRs awaiting approval; show them under separate **Approved** and **Waiting for reviewer** sections.
3. Within each approval section, group MRs by shared purpose or change, including related work across repositories. Keep unrelated MRs in separate groups. Include the repository name with each MR; order items by repository, then MR number.
4. For the Claude presentation, use Markdown links with the MR title as link text:

   ```
   ## Waiting for reviewer
   ### CI updates
   - [backend !6761 Fix CI steps](https://gitlab.com/...)
   ```

5. When asked for a PTAL export, use a compact, copyable list with the same approval sections and cohesion groups. Put one Markdown-linked MR per bullet and include its repository name.
6. Post to Slack only when asked, after the user says `go`, and only to the channel they named.
