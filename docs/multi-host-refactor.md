# Multi-host / multi-user refactor plan

Restructure the flake to stay coherent as it grows along three axes:
platform (darwin/nixos), host (`pro`, `nixden` VM, future host), and user
(`mostlyobvious`, `cm`, future CI runner).

## Decisions (settled)

- **Activation unifies on standalone home-manager.** `darwin-rebuild` does
  *system + account provisioning only*. Every user — including
  `mostlyobvious` — activates via its own `homeConfigurations.<user>`
  `activationPackage`, the way `cm` already does.
- **The CI runner is a dedicated sudo-less account on `pro`** (mirrors `cm`),
  with a deliberately minimal profile.

## Problems being fixed

1. `modules/darwin/` mixes nix-darwin **system** modules with **home-manager**
   modules that are merely macOS-only. Code comments apologize for it.
2. The user axis has no home: the per-user module lists are duplicated inline
   in `flake.nix` (owner imports `[common, darwin/home, github-runner-mrs]`;
   cm imports `[common, darwin/home]`).
3. Two activation mechanisms (owner integrated with `darwin-rebuild`, cm
   standalone) and hand-written per-target switch apps.

## Target layout

```
flake.nix          # thin: inputs + wiring + the targets table
lib/               # mkHome, mkDarwin, mkNixos, mkSwitchApps (moved out of flake.nix)
hosts/
  pro.nix          # darwin: hostname, casks, users = [ mostlyobvious cm ci ]
  nixden.nix       # nixos VM (from vms/nixden)
profiles/          # the USER axis (home-manager recipes)
  base.nix         # composes cross-platform modules/home/* (todays common.nix role)
  darwin.nix       # composes modules/hm-darwin/* (todays modules/darwin/home.nix role)
  mostlyobvious.nix# base + darwin + mrs-runner + identity/signing
  cm.nix           # base + darwin + signing/dotfilesDir/email
  ci.nix           # minimal: no editors/skills/identity
modules/
  home/            # unchanged module library (git, fish, neovim, ruby, claude, pi, eza, skills)
  hm-darwin/       # home-manager macOS modules pulled OUT of modules/darwin
  darwin/          # system-only (system, sudo, sshd, homebrew, account provisioning, runner-determinate)
```

Mental model: `modules/` = ingredients, `profiles/` = a user's recipe,
`hosts/` = which recipes run on which machine. Standalone `homeConfigurations`
and any integrated path both point at the *same* profile — no duplication.

## Module classification (for the stage-1 split)

Move to `modules/hm-darwin/` (home-manager):
`home.nix` (→ `default.nix`), `ghostty.nix`, `macos-defaults.nix`, `ssh.nix`,
`history.nix`, `zed.nix`, `github-runner-mrs.nix`.

Keep in `modules/darwin/` (nix-darwin system):
`default.nix`, `system.nix`, `sudo.nix`, `sshd.nix`, `homebrew.nix`, `cm.nix`,
`github-runner-determinate.nix`.

Relative-path notes:
- `github-runner-mrs.nix` uses `../../secretspec.toml`; `modules/hm-darwin/` is
  the same depth as `modules/darwin/`, so the path stays valid.
- `hm-darwin/default.nix` (renamed from `home.nix`) keeps its `./history.nix`
  etc. imports valid since those files move together.

## Stages (commit + verify per stage)

### Stage 1 — Split `modules/darwin` → `darwin` (system) + `hm-darwin` (home)
Mechanical, zero behavior change. Do this first.
- `git mv` the home-manager files into `modules/hm-darwin/`; rename
  `home.nix` → `hm-darwin/default.nix`.
- Update import sites in `flake.nix`:
  - `home-manager.users.${owner}.imports`: `./modules/darwin/home.nix` →
    `./modules/hm-darwin`; `./modules/darwin/github-runner-mrs.nix` →
    `./modules/hm-darwin/github-runner-mrs.nix`.
  - cm `homeModules`: `./modules/darwin/home.nix` → `./modules/hm-darwin`.
- Verify: `nix flake check` + `nix build --dry-run .#darwinConfigurations.pro.system`
  + `nix build --dry-run .#homeConfigurations.cm.activationPackage`.

### Stage 2 — `lib/` extraction + `profiles/`
- Move `mkHome`/`mkDarwin`/`mkDarwinApp`/`darwinApps` into `lib/`.
- Create `profiles/{base,darwin,mostlyobvious,cm}.nix`; collapse the two
  duplicated inline import lists into these.
- Rename the global `username` (owner concept). CAUTION: many modules
  destructure `{ username }` as a specialArg (`system.nix`, `cm.nix`,
  `history.nix`, `darwin/default.nix`, `vms/nixden/configuration.nix`). Either
  rename the let-binding to `owner` while keeping the module-facing arg key as
  `username` (means "this config's user"), or update every signature. Prefer
  the former to keep the change small.
- Verify as stage 1.

### Stage 3 — `hosts/` + targets table + generated apps + owner → standalone HM
Behavior-changing stage (owner's update path changes here).
- `hosts/pro.nix` declares hostname, casks/extraModules, `users`.
- Targets table in `flake.nix`, e.g.:
  ```nix
  targets = {
    pro                 = { host = "pro"; kind = "darwin"; };
    "pro:mostlyobvious" = { host = "pro"; kind = "home"; profile = "mostlyobvious"; };
    "pro:cm"            = { host = "pro"; kind = "home"; profile = "cm"; };
    nixden              = { host = "nixden"; kind = "nixos-vm"; };
  };
  ```
- `mkSwitchApps targets` derives `nix run .#pro:cm` etc.; `.#switch` runs the
  host system then activates each of its users, in order.
- Convert owner to standalone: drop `home-manager.darwinModules` wiring from
  `mkDarwin`; add a darwin `homeConfigurations.mostlyobvious`
  (system `aarch64-darwin`, `profiles/mostlyobvious.nix`, dotfilesDir +
  signingKey). Disentangle from the existing linux
  `homeConfigurations.${username}` (line ~268), which is the portable/VM one.
  The `mrs` runner LaunchAgent lives in `profiles/mostlyobvious.nix`.
- Verify: dry-build every target and **diff resulting store paths against the
  current build before activating**.

Resulting commands:
```
nix run .#switch          # host system + all its users + vms
nix run .#pro             # just the system (darwin-rebuild)
nix run .#pro:cm          # just one user
```

### Stage 4 — CI runner account (later)
- `modules/darwin/ci.nix` for account provisioning (mirror `cm.nix`:
  `users.knownUsers`, shell, `com.apple.access_ssh` ACL).
- `profiles/ci.nix` minimal — no personal git identity/signing, no editor
  config, no skills; only the job toolchain.
- Add `ci` to `hosts/pro.nix` users and a `pro:ci` target row.
- **CAVEAT:** a headless `ci` account has no Aqua (GUI) session, so the
  `github-runner-mrs` LaunchAgent pattern (Apple `container` XPC needs a
  per-user GUI domain) will not work as-is there. If CI jobs need Apple
  `container`, `ci` needs auto-login or a system LaunchDaemon variant. Resolve
  the container requirement before wiring the runner.

## Verification / rollback

- Each stage stays green: `nix flake check` (nixfmt + deadnix + `darwin-pro`
  build), plus dry-builds of affected targets.
- Commit per stage; each is independently revertible via git.
- Signing works now (`id_ed25519.pub`); no `--no-gpg-sign` needed.
