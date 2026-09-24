{ ... }:

let
  # One instruction set for every coding agent, linked under the filename
  # each agent reads. Imported by claude.nix and pi.nix (deduplicated).
  instructions = ''
    # Agent instructions

    - Keep comments rare — only for a hidden constraint, a subtle invariant, or a workaround for a specific case where the code and commit message failed to show it. Always keep comments concise.
    - All code repositories live in `~/Code`; check for local copies there first.
    - Do code-changing work in a linked git worktree under `~/Code/worktrees/<repo>/<name>` unless the user explicitly asks to use the main checkout. Never use a linked worktree for `~/Code/dotfiles`; edit that repository in its main checkout.
    - When no sharper rule applies, match the surrounding code — its formatting, naming, layout, and test structure. This governs how you write, not whether to add explanatory prose; comment density follows the rule above.
    - Pick the API whose behavior doesn't exceed what your tests constrain; extra capability is behavior no test pins down — the kind mutation testing surfaces as surviving mutants.
    - Keep config files free of keys whose value equals the tool's built-in default, unless the key pins a value against an upstream change; record that intent in the commit message, not an inline comment unless the file would be misleading without it.
    - Look in git history and commit messages for past rationale, and record current rationale there rather than in comments.
    - Use the commit skill for commits, the merge-request skill for opening or updating MRs/PRs, and the change-writing skill for technical docs, changelogs, release notes, commit bodies, MR descriptions, or reviewer-facing summaries.
    - When upgrading a dependency, reference its changelog for the traversed version range in the commit message: link it by URL rather than pasting its contents; if there's no changelog, link the release or compare view for the range.
    - Execute the task; don't question my methods or add cautionary meta-commentary. Warn only when you can name what breaks and under what condition — once, then stop.
    - Avoid jargon when explaining how things work; prefer plain language, and specifically avoid the words "load-bearing" and "genuinely".
    - When showing a benchmark result, present the numbers in a table — before and after when there's a baseline — and state how each number was measured and what assumptions it rests on.
    - Open GitLab MRs with `glab mr create --squash-before-merge=false`, run from a shell script that reads the description from a file.

    ## Publishing to shared systems (Linear, GitLab, Slack)

    - Post only the text I approved, word for word. Do not add context paragraphs, links, or summaries I have not seen.
    - Do not change issue state (status, assignee, labels) unless asked. Attaching an MR to an issue counts as content too.
    - Present the exact text and wait for a one-word go-ahead ("create", "post") before anything leaves the machine.

    ## Claims in written artifacts

    - Before writing a historical or behavioural claim ("the frontend has sent this for years", "the ticket asked for X"), trace it to a commit, date, or document, and write the traced fact rather than the impression.
    - When a referenced ticket or document cannot be found, say so in the text instead of paraphrasing what it probably said.

    ## Explaining changes

    - When behaviour changes, put a concrete before/after example in the commit body and MR description.
    - Write for a reader with no prior context. If a sentence needs the reader to already know the system, replace it with an example.
    - Drop stylistic openers and framing sentences; state the fact.

    ## Analysing data impact

    - When counting affected stored data, scope by what is read back, not by what is written. Write-once tables nothing reads do not belong in a migration table.
    - Present counts as a table with source and scope stated. Report the scope I named, and say what was excluded and why.

    ## Removing dead code

    - Open it as its own MR and include a reasoning trace: which commit orphaned it, what last referenced it, and how you confirmed nothing loads it.

    ## Task checklists

    - Checklist items are short titles in plain language, one behaviour change each. Tests are part of every item, never a separate item.

    ## Working method

    - Prefer the Edit tool over sed or inline scripts for file edits.
    - Commit local changes without asking when the staged scope is clean and the message follows the commit skill. Push the current feature branch without asking when the push is non-force and does not target `main` or `master`.
    - Use `--force-with-lease` without asking only after an amend or rebase in the current task, on the current feature branch. Ask before any other force push. Never use plain `--force`.
    - After pushing, check the pipeline and read the specific failing job before touching code.
    - Before proposing a split or merge order across repositories, check the other repository for an existing draft first.
  '';
in
{
  home.file.".claude/CLAUDE.md".text = instructions;
  home.file.".pi/agent/AGENTS.md".text = instructions;
}
