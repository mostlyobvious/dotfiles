# dotfiles

Nix-managed: nix-darwin for macOS system state, home-manager for every
account, NixOS for Linux VMs. One flake, pinned by `flake.lock`.

## Layout

- `hosts/` — the root of the tree, one file per machine: its system
  modules, every account (home module list, Homebrew casks), its VMs.
- `lib/` — turns the host tree into flake outputs: `mk-darwin.nix`
  (system), `mk-home.nix` (standalone home-manager per account),
  `apps.nix` (bootstrap/switch).
- `modules/` — nix-darwin and home-manager modules; each account picks
  its own list in `hosts/`.
- `config/` — raw dotfiles the modules deliver.
- `vms/` — Lima guests: NixOS config + `lima.yaml`.

Outputs mirror the tree: `darwinConfigurations.<host>`,
`homeConfigurations."<host>-<user>"` and `."<vm>"`,
`nixosConfigurations.<vm>`, plus a check per system and home.

## Apply

```sh
make         # = nix run .#switch
make check   # = nix flake check
```

`switch` derives the host from `scutil --get LocalHostName` and converges
everything in order: the nix-darwin system, each account's home (the
invoking user directly, other accounts via `sudo -u`), then each VM
(started via Lima, rebuilt from the read-only `/mnt/dotfiles` mount).

## Bootstrap fresh Mac

```sh
make bootstrap HOST=<host>   # one of hosts/
```

A pre-Nix shim only: starts the Xcode Command Line Tools installer if
missing, installs Determinate Nix, then delegates to
`nix run .#bootstrap -- <host>`, which installs Homebrew and runs the same
convergence as switch. Open a new terminal afterwards; from then on plain
`make`.

## Design

### Determinate owns Nix

The Determinate installer manages the daemon and `/etc/nix/nix.conf`;
nix-darwin runs with `nix.enable = false` so the two never fight. Extra
daemon settings go through `determinateNix.customSettings`, which lands in
`nix.custom.conf`.

### Unstable everywhere

`nixos-unstable` for all outputs, `home-manager`/`nix-darwin` follow
nixpkgs — one nixpkgs in the closure, and the shared modules evaluate
identically on host and VM. Determinism comes from `flake.lock`; upgrading
is a deliberate `nix flake update`.

### Dotfile delivery — in-store by default

Raw config files are delivered through the Nix store: read-only,
rollback-able, matching the flake revision. Out-of-store symlinks are the
exception, used only when the app owns the file — it rewrites it, edits it
from its UI, or needs a live edit loop (nvim, Zed, Ghostty, agent
settings).

Claude and pi `settings.json` are tracked but locally marked
`skip-worktree` because the agents rewrite them during normal use. To
commit a settings change: clear the bit, commit, restore it.

### Neovim plugins stay in vim.pack

`vim.pack` + `nvim-pack-lock.json` already pin plugins and work anywhere
with git + neovim. Nix's job for nvim is the binary and the config tree.

### Ruby — per-project devshells

Projects declare their Ruby in their own `flake.nix` + `.envrc`; the
shared module only enables `direnv` + `nix-direnv`.

### Homebrew — GUI casks only, zap

Casks and MAS apps are declared per account in `hosts/`; CLI tooling is
Nix except a couple of host-only tools. `cleanup = "zap"` makes the
declared lists the single source of truth; auto-update/upgrade off so a
switch is fast. nix-darwin never installs Homebrew — bootstrap and switch
do when absent.

### VM isolation

Nothing identity-, credential-, or host-bound crosses into modules shared
with VMs. SSH keys and config stay on the host; the VM uses its own.

### Theme

Nightfox (Duskfox dark, Dawnfox light) across terminals, editors, CLI
tools, and agent UI. Match new tool config to
<https://github.com/EdenEast/nightfox.nvim> when it supports theming.
