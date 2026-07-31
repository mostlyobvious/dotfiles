{ ... }:

let
  # One instruction set for every coding agent, linked under the filename
  # each agent reads. Imported by claude.nix and pi.nix (deduplicated).
  instructions = ''
    # Agent instructions

    - Keep comments rare — only for a hidden constraint, a subtle invariant, or a workaround for a specific case where the code and commit message failed to show it. Always keep comments concise.
    - All code repositories live in `~/Code`; check for local copies there first.
    - Linked git worktrees live in `~/Code/worktrees/<repo>/<name>`.
    - When no sharper rule applies, match the surrounding code — its formatting, naming, layout, and test structure. This governs how you write, not whether to add explanatory prose; comment density follows the rule above.
    - Pick the API whose behavior doesn't exceed what your tests constrain; extra capability is behavior no test pins down — the kind mutation testing surfaces as surviving mutants.
    - Keep config files free of keys whose value equals the tool's built-in default, unless the key pins a value against an upstream change; record that intent in the commit message, not an inline comment unless the file would be misleading without it.
    - Look in git history and commit messages for past rationale, and record current rationale there rather than in comments.
    - When upgrading a dependency, reference its changelog for the traversed version range in the commit message: link it by URL rather than pasting its contents; if there's no changelog, link the release or compare view for the range.
    - Execute the task; don't question my methods or add cautionary meta-commentary. Warn only when you can name what breaks and under what condition — once, then stop.
    - Avoid jargon when explaining how things work; prefer plain language, and specifically avoid the words "load-bearing" and "genuinely".
    - When showing a benchmark result, present the numbers in a table — before and after when there's a baseline — and state how each number was measured and what assumptions it rests on.
    - When opening a GitLab merge request, do not set commits to squash.
  '';
in
{
  home.file.".claude/CLAUDE.md".text = instructions;
  home.file.".pi/agent/AGENTS.md".text = instructions;
}
