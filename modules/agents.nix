{ config, lib, ... }:

let
  purposeBuiltTools = [
    "argo"
    "ast-grep"
    "devenv"
    "gcloud"
    "gh"
    "glab"
    "jq"
    "kubectl"
    "redocly"
    "rg"
    "secretspec"
    "tfenv"
    "vault"
    "yq"
  ];
  availableTools = lib.sort builtins.lessThan (
    lib.unique (
      lib.filter (tool: tool != null && builtins.elem tool purposeBuiltTools) (
        map (package: package.meta.mainProgram or null) config.home.packages
      )
    )
  );
  availableToolList = lib.concatMapStringsSep ", " (tool: "`${tool}`") availableTools;

  # One instruction set for every coding agent. Imported by claude.nix and
  # pi.nix (deduplicated).
  instructions = ''
    # Agent instructions

    - Keep comments rare — only for a hidden constraint, a subtle invariant, or a workaround for a specific case where the code and commit message failed to show it. Always keep comments concise.
    - All code repositories live in `~/Code`; check for local copies there first.
    - Do code-changing work in a linked git worktree under `~/Code/worktrees/<repo>/<name>` unless the user explicitly asks to use the main checkout. Never use a linked worktree for `~/Code/dotfiles`; edit that repository in its main checkout.
    - When no sharper rule applies, match the surrounding code — its formatting, naming, layout, and test structure. This governs how you write, not whether to add explanatory prose; comment density follows the rule above.
    - Before adding code, configuration, documentation, tests, or process, search for an existing part that can be removed or simplified to satisfy the request. After verification, make a subtraction pass and keep only what the required behaviour and tests constrain.
    - For non-trivial design or implementation, compare removal, simplification or reuse, and addition. Reject options that miss the requirement, then choose the smallest remaining interface.
    - Keep config files free of keys whose value equals the tool's built-in default, unless the key pins a value against an upstream change; record that intent in the commit message, not an inline comment unless the file would be misleading without it.
    - Look in git history and commit messages for past rationale, and record current rationale there rather than in comments.
    - Use the commit skill for commits, the merge-request skill for opening or updating MRs/PRs, and the change-writing skill for technical docs, changelogs, release notes, commit bodies, MR descriptions, or reviewer-facing summaries.
    - Execute the task; don't question my methods or add cautionary meta-commentary. Warn only when you can name what breaks and under what condition — once, then stop.
    - Avoid jargon when explaining how things work; prefer plain language, and specifically avoid the words "load-bearing" and "genuinely".
    - Do what I asked and no more. Answer the question I asked, not a neighbouring one; when I ask to propose, explain, or review, change nothing; leave settings, versions, and files I did not name as they are.
    - Once I approve a plan or slice, carry it through to its end without stopping for confirmation between steps. Stop only for a decision the plan does not settle.
    - When I exclude a person, ticket, or MR from text ("stop mentioning X"), keep it out of everything that follows in the session.

    ## Publishing to shared systems

    - Post only the text I approved, word for word. Do not add context paragraphs, links, or summaries I have not seen. This covers published pages too: keep approved text and its layout as approved, without added styling or sections.
    - Draft only the posts I asked for; do not offer drafts for other systems on your own.
    - Do not change issue state (status, assignee, labels) unless asked. Attaching an MR to an issue counts as content too.
    - Before opening an MR or publishing approved text, present the exact content and destination, then wait for `go`. `go` authorizes only the action and content presented.
    - Run each write to a shared system as its own tool call, after the call that builds its input has succeeded and shown the input.

    ## Writing to me

    - Answer first. The opening sentence states the result, decision, or answer; supporting detail follows in falling order of importance.
    - For status updates: state, then blockers, then next step. No chronological narration of what you did.
    - Introduce one new concept at a time. Define a term before its first use; never use it first and explain after.
    - A link is not an explanation; the reply must make sense without opening it.
    - Use precise verbs instead of "is/does/handles" and noun forms ("validate", not "perform validation").
    - Phrase positively: "accepts empty input", not "doesn't fail on empty input", unless that reads worse.
    - Active voice by default; name what acts.
    - Every "it", "this", "that" must point to one thing in the same paragraph; otherwise repeat the noun.
    - Headings say what the section concludes, not its topic.
    - Vary sentence shape; no bold lead-ins or groups of three as habits.

    ## Removing dead code

    - When the requested change makes code dead, remove it in the same MR. Remove pre-existing dead code in its own MR.
    - Either way, include a reasoning trace: which commit orphaned it, what last referenced it, and how you confirmed nothing loads it.

    ## Tests

    - Write tests in specification-by-example style: each test reads as a domain example with its inputs and expected outcome, keeping setup plumbing out of the test body.

    ## Dependencies

    - Upgrade only what the task names. For Ruby gems, run `bundle update <gem> --conservative --cooldown=0` so the named gem and what it requires move, and nothing else.

    ## Long-running work

    - During long-running work, report progress at each milestone or every few minutes: what finished, what runs now, and the expected remaining time.

    ## Task checklists

    - Checklist items are short titles in plain language, one supported behaviour change each. Tests belong with the item when they pin intended behaviour; do not add negative tests for deleted behaviour unless the absence is itself a public contract or regression risk.

    ## File editing

    - Use Edit for targeted changes to existing files.
    - Use Write for new files and complete rewrites.
    - Use Bash for inspection and verification. Repository-owned formatters, generators, and dependency commands may update files.
    - If Edit cannot express a targeted change, report the blocker before choosing another editing method.

    ## Tools

    - Purpose-built profile commands on this host: ${availableToolList}.
    - Before writing an ad hoc validator in a general-purpose language, use a purpose-built profile or repository command when one fits.
    - Fish is the login shell; prefer Fish for standalone scripts.

    ## Working method

    - Commit local changes without asking when the staged scope is clean and the message follows the commit skill. Push the current feature branch without asking when the push is non-force and does not target `main` or `master`.
    - Use `--force-with-lease` without asking only after an amend or rebase in the current task, on the current feature branch. Ask before any other force push. Never use plain `--force`.
    - Before proposing a split or merge order across repositories, check the other repository for an existing draft first.
    - Do not reuse services from another checkout unless asked. Each agent task that needs local services must use its own worktree and run `devenv up -d` from that worktree's repository root so logs, state, and process-compose control stay isolated. Stop only that worktree's services with `devenv down` when finished.
    - Run a worktree's app commands through `devenv shell --` from that worktree, so they connect to its own services rather than ones named in the inherited environment.

    ## Checking before claiming

    - Before explaining a failure, run the checks that would confirm or rule out each cause, and report what they showed. Do not offer causes you have not checked.
    - Before saying something is missing (a test, a file, a handler), search for it and name where you looked.
    - State a caveat once, when you can name what breaks and under what condition. Do not repeat it in later replies.
    - When waiting on something, check what it is waiting for and say that, instead of promising to act later.
    - Confidence comes from a check you ran, not from phrasing. If you have not checked, check; do not hedge.
  '';
in
{
  programs.claude-code.context = instructions;
  programs.pi-coding-agent.context = instructions;
}
