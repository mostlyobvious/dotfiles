# Multi-host / multi-user refactor plan

Restructure the flake for a fleet of two darwin machines — `pro` (personal,
this one) and `cm` (work only, incoming) — each with one or more admin
accounts, any number of non-admin accounts, and any number of single-user
linux VMs.

**The host is the root of the tree.** One file per machine describes
everything that machine is: its architecture, its system modules, its
accounts (each flagged admin or not, each a flat list of feature modules),
and its VMs (each a single-user guest). There is no separate table beside the
hosts — a user or VM exists precisely because it appears inside a host.
Admin-ness is a property of the account, not a host-level pointer, so a host
may have zero, one, or several admins.

**Two commands, total.** `bootstrap <host>` on a fresh machine, `switch`
forever after. Both run from the admin account with sudo and do *everything*
that machine needs — its system, every account's home, its VMs.

## Decisions (settled)

- **The host tree replaces the flat pair-table.** `hosts/<host>.nix` returns
  an attrset with `arch`, a `system` module, a `users` map, and a `vms` map
  (name → single-user guest). The flake output names
  (`homeConfigurations."pro-cm"`, `nixosConfigurations.nixden`) are derived by
  joining host + user; you never type them — the two commands cover
  everything.
- **Admin status is per account.** Each `users` entry is
  `{ admin ? false; key ? null; modules; }`: `admin` grants OS-level admin
  (created at install, runs `switch`), `key` is that account's SSH public key
  (only meaningful on admins — authorized on the non-admin accounts by
  `account.nix`), `modules` is the home list. A host may have zero, one, or
  several admins. `system.primaryUser` (nix-darwin's per-user settings anchor)
  is the sole admin automatically; only a multi-admin host must mark exactly
  one account `primary = true` (asserted).
- **Accounts are fully flat and self-describing.** Each entry's `modules` is a
  flat list naming every feature module it wants (`core.nix`, `git.nix`,
  `ghostty.nix`, …), ~15–20 lines. Duplication across accounts is deliberate:
  reading one entry tells you everything that account has; the price is that
  "give everyone X" means editing every entry.
- **`modules/` is one flat directory — no subgroups.** One file per feature,
  ~24 files. The home-vs-system distinction is carried by which list
  references a file (a `users`/`vms.home` entry vs a host's `system`), not by
  directory structure. Misplacing a file fails the build (wrong option
  namespace) and the checks catch it. All aggregator files dissolve
  (`modules/darwin/home.nix`, `modules/darwin/default.nix`, `common.nix`).
- **`core.nix` heads every account; `darwin-core.nix` heads every mac's
  `system`.** `core.nix`: the `my.*` option declarations,
  `home.username`/`homeDirectory`/`stateVersion`,
  `programs.home-manager.enable`, manual/hushlogin. `darwin-core.nix` (the
  content of today's `modules/darwin/default.nix`): machine naming from the
  host name, admin account declaration, Determinate hand-off
  (`nix.enable = false`), `system.primaryUser`, `stateVersion`. No feature
  content in either.
- **Per-account identity** (email, signing key, dotfilesDir, Logseq graphs,
  homeDirectory) is an inline module at the end of the account's list, not a
  bespoke `mkHome` parameter.
- **Work tools are per-topic feature files** — `kubernetes.nix` (kubectl,
  argo-workflows, gcloud + GKE auth plugin), `vault.nix`, `redocly.nix` —
  matching the existing per-tool granularity (`eza.nix`, `pi.nix`). They
  appear only in accounts on the work host, by convention.
- **`switch` does everything, run from an admin account with sudo.** In order:
  1. `darwin-rebuild switch` — system + account *provisioning* (each non-admin
     account's authorized keys, `com.apple.access_ssh` ACL, login shell).
  2. the invoking admin's own home, activated directly.
  3. every *other* account's home (non-admins and any other admins), via
     `sudo -u <user> -H …/activate` with `HOME_MANAGER_BACKUP_EXT=hm-bak`
     (runs as that user, so files are owned correctly; builds go through the
     shared nix store).
  4. each VM: start it, `nixos-rebuild switch` inside, activate the guest's
     home from the mount.
  The split in steps 2–3 is "am I the invoking user", not admin-ness; any
  admin can run `switch`. A non-admin can't (step 1 needs sudo).
- **Activation carries no secrets, so crossing accounts is safe.** A home
  activation only lays down config files that already live in this public
  repo — it never touches a keychain, token, or SSH agent. The work account's
  real isolation (its own keychain and credentials) is untouched whether admin
  or the account itself runs the idempotent activation. This is why the old
  "privilege boundary" that made each account self-activate is dropped.
- **CAVEAT — cross-account activation assumes no background agent.** Step 3 is
  clean only while an account activated via `sudo -u` has no home-manager
  LaunchAgent/service: loading one targets that user's GUI (Aqua) session,
  which the admin session can't reach. No account has such an agent today (the
  GitHub runner that used to live on the admin account was removed), so this
  holds trivially. It only becomes a real constraint if a future account
  (e.g. a headless `ci` runner) needs an agent — see the closing section.
- **`bootstrap <host>` is the only command that names a machine.** A fresh
  machine's name matches no host, so `switch`'s hostname check would refuse
  it. `bootstrap` takes the host name explicitly, installs Homebrew if
  missing, sets the machine's name, then runs the full `switch` sequence.
  Every run after is plain `switch`, which resolves the host from
  `scutil --get LocalHostName` and refuses an unknown name.
- **The VM gets the repo via a read-only lima mount, not rsync.** `lima.yaml`
  mounts the dotfiles working copy (only the repo — the no-home-dir-mount
  isolation stance stays); the guest builds `nixos-rebuild` and its home
  straight from the mount. The rsync steps and `/tmp/lima-*` staging dirs go
  away. (Guest builds need `--no-link` or a cd to $HOME: `nix build` cannot
  write `./result` into a read-only mount.)
- **`account.nix`** (renamed from `modules/darwin/cm.nix`) is parametric over
  the host's non-admin account names and the set of admin `key`s; it
  provisions each non-admin account's authorized keys, ACL, and fish
  `UserShell`. No account *creation* — that stays manual (System Settings /
  sysadminctl).
- **`nix flake check` builds every darwin target** — both hosts' `system` and
  every account's home, derived from the tree so new accounts are covered
  automatically. Linux targets (VM system + guest home) sit under
  `checks.aarch64-linux` and build only where a linux builder runs them.

## Assumptions (stated, not enforced)

- Hostnames are unique across the whole fleet, VMs included. A VM lives under
  its host in the tree, so this is naturally true unless two hosts name a VM
  the same; the derived output names would then collide.
- `pro`'s `cm` account survives the arrival of host `cm` until work migrates;
  removing it is deleting one entry from `hosts/pro.nix`.

## Problems being fixed

1. Aggregator/bundle files (`modules/darwin/default.nix`, `darwin/home.nix`,
   `common.nix`) hide what an account or machine actually gets, and
   `modules/darwin/` mixes system modules with home-manager modules that are
   merely macOS-only — the code comments apologize for it.
2. The user axis has no home: per-account module lists are duplicated inline in
   `flake.nix` (owner, cm) *and* in `vms/nixden/configuration.nix` (guest),
   behind the bundle files — no single place shows what an account gets.
3. Two activation implementations (owner integrated with `darwin-rebuild`,
   cm standalone; the VM guest has *both*) and a pile of hand-written apps
   (`cm-switch`, `vm-switch`'s `case`, `home`, `update`) — all subsumed by two
   commands over the tree.
4. The global `username` let-binding means "owner" in some modules and "this
   config's user" in others.
5. `mkHome` grew bespoke parameters (`dotfilesDir`, `signingKey`, `email`,
   `homeDirectory`) that duplicate what inline `my.*`/`home.*` modules already
   express.

## Target layout

```
flake.nix          # thin: inputs + `hosts = { pro = import …; cm = …; }` + wiring
lib/               # mkDarwin, mkHome, mkApps, mkChecks (walk the host tree)
hosts/
  pro.nix          # { arch, system, users (each {admin?,key?,modules}), vms }
  cm.nix           # work host, same shape
vms/nixden/        # configuration.nix, lima.yaml (gains the repo mount)
modules/           # ONE flat directory, one file per feature:
                   # home:   core, cli, git, fish, neovim, ruby, claude, pi,
                   #         eza, skills, kubernetes, vault, redocly,
                   #         ghostty, zed, ssh, fonts, logseq, macos-defaults,
                   #         history
                   # system: darwin-core, system, sudo, sshd, homebrew, account
```

Mental model: `modules/` = one file per feature; `hosts/<host>.nix` = the
whole machine — its system, its accounts and what each gets, its VMs.

## The host tree

`hosts/pro.nix` (module paths are `../modules/…` from `hosts/`):

```nix
{
  arch = "aarch64-darwin";

  # nix-darwin system module for this machine
  system = {
    imports = [
      ../modules/darwin-core.nix
      ../modules/system.nix
      ../modules/sudo.nix
      ../modules/sshd.nix
      ../modules/homebrew.nix
      ../modules/account.nix
    ];
    # host-only config (extra casks, …) inline here
  };

  # every account on this machine; the invoking admin activates directly,
  # every other account via sudo -u
  users = {
    mostlyobvious = {
      admin = true;
      key = "ssh-ed25519 AAAA… mostlyobvious@pro";  # authorized on non-admin accounts
      modules = [
        ../modules/core.nix
        ../modules/cli.nix
        ../modules/git.nix
        ../modules/fish.nix
        ../modules/neovim.nix
        ../modules/ruby.nix
        ../modules/claude.nix
        ../modules/pi.nix
        ../modules/eza.nix
        ../modules/skills.nix
        ../modules/ghostty.nix
        ../modules/zed.nix
        ../modules/ssh.nix
        ../modules/fonts.nix
        ../modules/logseq.nix
        ../modules/macos-defaults.nix
        ../modules/history.nix             # iCloud-backed; this account only
        (
          { pkgs, ... }:
          {
            home.packages = [ pkgs.lima pkgs.rtl_433 ];   # runs the VMs; radio tinkering
            my.logseqGraphs = [ "Notes/mostlyobvious" "Notes/hraba.gs" ];
          }
        )
      ];
    };

    cm = {
      # admin defaults false; no key — reached only via sudo -u from an admin
      modules = [
        ../modules/core.nix
        ../modules/cli.nix
        ../modules/git.nix
        ../modules/fish.nix
        ../modules/neovim.nix
        ../modules/ruby.nix
        ../modules/claude.nix
        ../modules/pi.nix
        ../modules/eza.nix
        ../modules/skills.nix
        ../modules/ghostty.nix
        ../modules/zed.nix
        ../modules/ssh.nix
        ../modules/fonts.nix
        ../modules/logseq.nix
        ../modules/macos-defaults.nix
        ../modules/kubernetes.nix
        ../modules/vault.nix
        ../modules/redocly.nix
        {
          my.dotfilesDir = "/Users/cm/dotfiles";
          my.signingKey = "/Users/cm/.ssh/id_ed25519.pub";
          my.userEmail = "pawel.pacana@chattermill.io";
          my.logseqGraphs = [ "Documents/CM" ];
        }
      ];
    };
  };

  # each VM is a single-user linux guest; its account is declared by its nixos config
  vms = {
    nixden = {
      arch = "aarch64-linux";
      user = "mostlyobvious";
      system = ../vms/nixden/configuration.nix;
      home = [
        ../modules/core.nix
        ../modules/cli.nix
        ../modules/git.nix
        ../modules/fish.nix
        ../modules/neovim.nix
        ../modules/ruby.nix
        ../modules/claude.nix
        ../modules/pi.nix
        ../modules/eza.nix
        ../modules/skills.nix
        {
          home.homeDirectory = "/home/mostlyobvious.guest";
          my.dotfilesDir = "/mnt/dotfiles";            # the read-only lima mount
          programs.zed-editor = {
            enable = true;
            installRemoteServer = true;
          };
        }
      ];
    };
  };
}
```

`flake.nix` stays thin:

```nix
hosts = {
  pro = import ./hosts/pro.nix;
  cm  = import ./hosts/cm.nix;
};
```

Derived by walking the tree (in `lib/`):

- `darwinConfigurations.<host>` from each host's `arch`/`system` and the
  admin accounts (primaryUser + `users.users.<admin>`); `account.nix` receives
  the non-admin account names and the set of admin `key`s.
- `homeConfigurations."<host>-<user>"` from every `users` entry's `modules`
  and every `vms.<vm>.home` (arch from the host or the vm). Internal build
  targets; never typed.
- `nixosConfigurations.<vm>` from each `vms` entry's `system`.
- `apps.bootstrap` and `apps.switch` (see above). No per-target apps.
- `checks` from the same walk, split by arch.

Resulting commands:

```
nix run .#bootstrap -- cm   # first run on a new machine: names it, then full switch
nix run .#switch            # this machine: system + all accounts + all VMs
```

## Module moves (for stages 1–2)

Everything flattens into `modules/` (no subdirectories):

- From `modules/home/`: `git.nix`, `fish.nix`, `neovim.nix`, `ruby.nix`,
  `claude.nix`, `pi.nix`, `eza.nix`, `skills.nix` move up unchanged.
- From `modules/darwin/`: `ghostty.nix`, `zed.nix`, `ssh.nix`, `fonts.nix`,
  `logseq.nix`, `macos-defaults.nix`, `history.nix` (home-manager) and
  `system.nix`, `sudo.nix`, `sshd.nix`, `homebrew.nix` (nix-darwin) move up
  unchanged.

Dissolved bundle files:
- `modules/darwin/home.nix` — deleted. Its imports become explicit account
  entries; its two packages (`lima`, `rtl_433`) move into the admin account
  on `pro` (only account that runs VMs / does radio).
- `modules/darwin/default.nix` — imports dissolve into each host's `system`;
  its own content (machine naming, admin account, Determinate hand-off,
  `primaryUser`, `stateVersion`) becomes `modules/darwin-core.nix`.
- `modules/home/common.nix` — split into `core.nix` (option declarations +
  username/homeDirectory/stateVersion + home-manager/manual/hushlogin) and
  `cli.nix` (fd, gh, jq, ripgrep, fzf, direnv, secretspec, devenv, glab).
  `stylua` and `lua-language-server` move into `neovim.nix`.

New feature files: `kubernetes.nix` (kubectl, argo-workflows, gcloud + GKE
auth plugin), `vault.nix`, `redocly.nix` — extracted from the `pro:cm` inline
block in `flake.nix`. Renamed: `cm.nix` → `account.nix` (stage 2).

## Stages (commit + verify per stage)

### Stage 0 — Delete debris
`vms/nixden/` contains an untracked full copy of the repo (a past rsync ran
with the wrong working directory). Only `configuration.nix` and `lima.yaml`
are tracked; delete the rest.

### Stage 1 — Flatten `modules/`, dissolve the aggregators
Mechanical, zero behavior change. Do this first.
- `git mv` every feature file up into `modules/`.
- Delete `home.nix` and `darwin/default.nix` as aggregators: expand their
  import lists inline at the usage sites (`flake.nix` owner + cm +
  `mkDarwin`), carve `darwin-core.nix` out of `default.nix`'s own content,
  park `lima`/`rtl_433` in the owner's inline list.
- Verify: `nix flake check` + `nix build --dry-run .#darwinConfigurations.pro.system`
  + `nix build --dry-run .#homeConfigurations.cm.activationPackage`.

### Stage 2 — Dissolve common.nix; lib/; feature files; account.nix
Still zero behavior change.
- Split `common.nix` into `core.nix` + `cli.nix`; move stylua/lua-language-server
  into `neovim.nix`; expand the import lists at every site.
- Extract `kubernetes.nix`, `vault.nix`, `redocly.nix` from cm's inline block.
- Move `mkHome`/`mkDarwin`/`mkDarwinApp`/`darwinApps` into `lib/`.
- Rename `cm.nix` → `account.nix`, parametric over a non-admin account list
  and the set of admin public keys. No account creation.
- De-hardcode the owner. CAUTION: many modules destructure `{ username }` as a
  specialArg (`system.nix`, `account.nix`, `history.nix`, `darwin-core.nix`,
  `vms/nixden/configuration.nix`) where it sometimes means "owner" and
  sometimes "this config's user". Keep the module-facing arg key `username`
  meaning "this config's user"; the primary/admin accounts flow from the
  `users` map's `admin` flags.
- Verify as stage 1.

### Stage 3 — Host tree, two commands, owner → standalone HM
Behavior-changing stage (owner's update path changes here).
- Add `hosts/pro.nix` as the tree above; `flake.nix` becomes
  `hosts = { pro = import …; }` + the `lib/` walk. Slim `mkHome` to consume an
  account's module list (drop the bespoke parameters).
- Replace every hand-written app with `bootstrap` + `switch`: `switch`
  resolves the host by hostname and refuses an unknown one, then runs the
  four-step sequence (system → invoking admin's home → every other account via
  `sudo -u` → VMs); `bootstrap <host>` names the machine and skips the assert.
  `switch`'s VM step keeps today's rsync semantics until stage 4.
- Convert owner to standalone: drop `home-manager.darwinModules` wiring from
  `mkDarwin`; the admin `users` entry is now activated by `switch` step 2.
  Drop the portable `homeConfigurations.mostlyobvious`. Remove the now-dead
  `/etc/profiles/per-user/…/bin` entry from `fish.nix` — with no
  `useUserPackages` anywhere on darwin that path no longer exists.
- Extend `checks` per the decision (both hosts' systems + every account home;
  linux under `checks.aarch64-linux`).
- Verify: dry-build every derived target and **diff resulting store paths
  against the current build before activating**.

### Stage 4 — VM unification (standalone guest + mount)
- Strip the integrated home-manager block from `vms/nixden/configuration.nix`;
  the `vms.nixden.home` list is the single source for the guest's home.
- Add the read-only dotfiles mount to `lima.yaml` (mount point
  `/mnt/dotfiles`); drop rsync and `/tmp/lima-*` staging from `switch`. Guest
  flow: `sudo nixos-rebuild switch --flake /mnt/dotfiles#nixden`, then build +
  activate the guest home with `--no-link`.
- Note: changing `lima.yaml` mounts requires recreating or editing the
  existing `nixden` instance (`limactl edit` / delete + start).
- Verify: `switch` end-to-end on pro, including the VM.

### Stage 5 — Bring up host `cm`
- `hosts/cm.nix` — a single `mostlyobvious` account with `admin = true`,
  mirroring `pro`'s `cm` account (work email, `Documents/CM` graph, work tool
  files); no non-admin accounts, no VMs yet.
- On the new machine: install nix + homebrew, then `nix run .#bootstrap -- cm`.
- `darwinConfigurations.cm` and its account home are already in `checks` from
  stage 3's tree walk, so they can't rot before the machine arrives.
- With no non-admin accounts, `account.nix` authorizes nothing; the admin's
  own `key` is irrelevant until this host gains a non-admin account, so it can
  be filled in later. `account.nix` must tolerate an admin whose `key` is null.

## What the finished design supports without further work

An extra minimal account (e.g. a `ci` runner) is a new `users` entry with a
thin module list — nothing structural needed, since `cm` already exercises the
provision-and-`sudo -u`-activate path. The one thing this model can't do
cleanly is run a *headless background agent* in such an account: starting a
LaunchAgent needs that account's own GUI (Aqua) session, which the admin's
session can't reach (Apple `container` XPC has the same requirement). An
agent-bearing service therefore has to live on an account with a real login
session — on an admin account activated directly, not a `sudo -u` one. (This
is why the GitHub `mrs` runner, when it existed, had to sit on the admin
account; it has since been removed from the repo and the machine.) Cross that
bridge (auto-login or a system LaunchDaemon variant) only if and when a
dedicated headless runner is actually needed.

## Verification / rollback

- Each stage stays green: `nix flake check` (nixfmt + deadnix + the
  tree-derived builds), plus dry-builds of affected targets.
- Commit per stage; each is independently revertible via git.
- Signing works now (`id_ed25519.pub`); no `--no-gpg-sign` needed.
