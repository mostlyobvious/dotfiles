# Agent hooks

`agent-hooks` provides the shared policy and worktree lifecycle used by Claude
Code and pi. It builds two native executables:

- `agent-guard` inspects shell commands before execution and adds reminders
  after selected tool calls.
- `agent-worktree` creates linked worktrees and stops worktree-local devenv
  services after the last agent session releases them.

The agent integrations translate host events into JSON. The Ruby code owns the
behaviour, so Claude Code and pi apply the same rules.

## Architecture

```text
Claude Code hooks                         pi extension
       │                                      │
       └──────────── JSON events ─────────────┘
                              │
                 ┌────────────┴────────────┐
                 ▼                         ▼
           agent-guard               agent-worktree
        stateless decisions       stateful coordination
                 │                         │
       exit status / reminder       Git, devenv, state file
```

Both executables read one JSON event from standard input. Blocking messages and
operational errors go to standard error. `agent-guard` can also return a JSON
reminder on standard output; `agent-worktree` returns a created worktree path on
standard output.

## Dotfiles integration

`modules/profiles/darwin-home.nix` imports both `modules/claude.nix` and
`modules/pi.nix`, so every Darwin home profile installs the hooks.

For Claude Code, `modules/claude.nix` builds both Nix packages and links their
executables to stable paths under `~/.claude/hooks/`. The out-of-store
`config/claude/settings.json` registers those paths for pre-tool, post-tool,
worktree creation, activity, and session-end events.

For pi, `modules/pi.nix` adds both executables to pi's `PATH` and links
`config/pi/extensions/` to `~/.pi/agent/extensions`. Pi loads
`agent-guard.ts`, which translates pi events, invokes the appropriate
executable by name, and injects guard reminders into tool results.

`packages/agent-guard.nix` and `packages/agent-worktree.nix` compile the Ruby
entry points with Spinel and install standalone executables. `make switch`
builds and activates the packages through Home Manager.

## Guard flow

`AgentHooks::Guard` has two paths:

1. A pre-tool event parses the shell source once and evaluates an ordered list
   of policies. The first blocking decision supplies exit status `2` and the
   reason shown to the agent.
2. A post-tool event recognizes actions that require a follow-up, such as a Git
   push or an edit to `mr-description.md`, and returns additional context to the
   agent.

`guard/shell_command.rb` turns shell source into normalized command
invocations. It accounts for quoting, command chains, `env`, leading variable
assignments, and `git -C`. Dynamic command construction with backticks or
`$(...)` is rejected because the guard cannot reliably know which command the
shell will execute. A reviewed script is the escape hatch for syntax outside
this inspectable subset.

`guard/policies.rb` keeps each rule independent while preserving policy order:

1. reject unsupported shell syntax;
2. protect Git and merge-request operations;
3. reject in-place shell edits;
4. require the change-writing skill before publishing prose;
5. reject agent co-author attribution;
6. enforce worktree entry through the session host.

The explicit dispatch in `Policies.evaluate` is intentional. Spinel must see
calls to the nested policy modules when it compiles the native executable.

## Worktree flow

`AgentHooks::Worktree` dispatches lifecycle events and coordinates focused
internal modules:

- `Creator` discovers the main checkout and creates or reuses the named branch
  under `~/Code/worktrees/<repository>/<name>`.
- `Devenv` recognizes successful `devenv up` commands and stops services with
  `devenv down`.
- `LeaseDecider` decides ownership transitions without reading files or running
  commands.
- `StateFile` serializes access to persisted ownership state.
- `CommandRunner` provides one boundary for Git and devenv subprocesses.

```text
successful devenv up
        │
        ▼
claim lease for session + worktree
        │
        ├── activity or heartbeat ──► refresh lease
        │
        └── session end / expiry ───► release lease
                                           │
                                  last owner released?
                                           │ yes
                                           ▼
                                      devenv down
```

A worktree can have several owning sessions. `agent-worktree` stops its devenv
services only after all leases disappear. This prevents one session from
stopping services still used by another. Activity refreshes existing leases;
leases expire after seven days so an interrupted session cannot retain services
forever.

State lives at `$XDG_STATE_HOME/agent-worktree/state.json`, or
`~/.local/state/agent-worktree/state.json` when `XDG_STATE_HOME` is unset.
Updates take an exclusive file lock and replace the JSON file atomically. A
failed `devenv down` leaves the root in state with no owners, allowing the next
event to retry cleanup. The loader also migrates the earlier session-oriented
state shape.

Worktree creation follows these rules:

- Resolve the main checkout through Git's common directory instead of assuming
  the current directory is the main checkout.
- Keep the `dotfiles` repository in its main checkout.
- Start new branches from `origin/HEAD` when available, falling back to `HEAD`.
- Attach an existing local branch instead of trying to recreate it.
- Run `devenv allow` when the new worktree contains `devenv.nix`; authorization
  failure reports an error but keeps the successfully created worktree.
- Print the destination and let the session host move the whole session there.
  A shell `cd` would affect only one command and leave later commands in the
  original checkout.

## Design choices

### One policy implementation serves both agents

Claude Code and pi expose different hook APIs. Their adapters translate events
and keep policy in Ruby. This avoids two sets of regular expressions and
lifecycle rules drifting apart.

### Guarding and lifecycle remain separate executables

Command policy is stateless and latency-sensitive. Worktree management owns
persistent state and subprocess cleanup. Separate entry points keep those
failure modes and interfaces independent while sharing the same packaging and
test environment.

### Decisions stay separate from effects

`LeaseDecider` receives a state snapshot and emits state transitions. File
locking, process execution, Git discovery, and devenv control sit behind small
modules. Tests can constrain lifecycle behaviour without starting real
services, while process-level tests still verify the executable boundary.

### Worktree services use leases rather than process identity

Agent processes can restart or miss shutdown hooks, and several sessions can
share one worktree. Timestamped per-session leases model the ownership that
matters directly and permit both concurrency and eventual cleanup.

### Native binaries keep deployment self-contained

The source remains ordinary Ruby for readable unit tests. Nix compiles each
entry point with Spinel so installed hooks do not depend on a user Ruby runtime.
The flake check runs the unit suite under CRuby, exercises both compiled
executables, checks Syntax Tree formatting, and runs Mutant against both public
modules.

## Changing the hooks

Keep host adapters limited to event translation. Add policy to
`guard/policies.rb`, lifecycle decisions to `worktree/lease_decider.rb`, and
side effects to the matching boundary module. Run the repository check from the
dotfiles root:

```sh
make check
```
