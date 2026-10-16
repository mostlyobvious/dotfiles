---
name: my-mrs
description: List my open MRs waiting for review, grouped by repository, ready to paste into Slack. Use when asked for my open, non-draft, or unapproved MRs, MRs waiting for review, or an MR digest.
---

# My MRs

## Procedure

1. Fetch my open non-draft MRs across all projects: `glab api --paginate "merge_requests?scope=created_by_me&state=opened&wip=no&per_page=100"`. Drop `wip=no` when asked to include drafts.
2. For each MR, read approvals with `glab api projects/<project_id>/merge_requests/<iid>/approvals` and drop approved MRs unless asked to keep them.
3. Group by repository; within a group, order by MR number ascending.
4. Output Slack-ready markdown, one line per MR, as a link with the title as text:

   ```
   *backend*
   • <https://gitlab.com/...|!6761 Title>
   ```

5. Post to Slack only on a "post" go-ahead, to the channel the user named.
