# dotfiles

Nix-managed: nix-darwin for macOS system state, home-manager for every
account, and NixOS for Linux VMs. This flake owns machine orchestration
and pins every input in `flake.lock`.

## Layout

- `hosts/`: the root of the tree, with one file per machine containing
  its system modules, Homebrew casks, accounts, and VMs.
- `lib/`: turns the host tree into flake outputs through `mk-darwin.nix`,
  `mk-home.nix`, and `apps.nix`.
- `modules/`: nix-darwin and home-manager modules selected by each
  account in `hosts/`.
- `config/`: raw dotfiles delivered by the modules.
- `vms/`: Lima guests containing NixOS configuration and `lima.yaml`.

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

### The dotfiles flake owns switching

`hosts/cm.nix` keeps the work machine in the same host tree and imports
`inputs.chattermill.homeModules.default` for private work settings. The
`chattermill` repository remains a separate pinned flake input. Evaluating
or switching the `cm` configuration requires SSH access to that repository.

### Unstable everywhere

All outputs use `nixos-unstable`. `home-manager` and `nix-darwin` follow
nixpkgs, leaving one nixpkgs in the closure and making shared modules
evaluate identically on the host and VM. `flake.lock` provides
determinism; `nix flake update` performs deliberate upgrades.

### Dotfile delivery defaults to the Nix store

Config lives inline in `modules/` as program options or Nix strings. The
Nix store delivers read-only files that match the flake revision and can
be rolled back. `config/` holds only exceptions where an application owns
the file, rewrites it through its UI, or needs a live edit loop, such as
Neovim, Zed, and agent settings.

Claude and pi `settings.json` are tracked but locally marked
`skip-worktree` because the agents rewrite them during normal use. To
commit a settings change: clear the bit, commit, restore it.

### Neovim plugins stay in vim.pack

`vim.pack` + `nvim-pack-lock.json` already pin plugins and work anywhere
with git + neovim. Nix's job for nvim is the binary and the config tree.

### Ruby uses per-project development environments

Projects declare Ruby in their own `devenv.nix`; the shared module only
enables `direnv` and `nix-direnv`.

### Homebrew manages GUI applications

Casks and MAS apps are declared per host in `hosts/`; Nix provides CLI
tooling except for a few host-only tools. `cleanup = "zap"` makes the
declared lists the single source of truth. Automatic updates and upgrades
remain disabled to keep switching fast. nix-darwin manages an existing
Homebrew installation; bootstrap and switch install Homebrew when absent.

Apple's `container` CLI is installed from its signed package, not the
Homebrew formula. The formula's binaries are ad hoc signed; the signed
package places the CLI at `/usr/local/bin/container`. `make switch`
installs the pinned 1.6.0 package after Homebrew removes the formula, and
installs an updated package when the pin changes. Before an install or
upgrade, activation stops any running container services. The package
requires macOS 26 or later. The `cm` host's launch agent starts the CLI
from its package path. See [Apple's releases](https://github.com/apple/container/releases).

### VM isolation

Nothing credential- or host-bound crosses into modules shared with VMs.
SSH keys and config stay on the host; the VM uses its own. Commit
identity (name, email) does cross, deliberately: work done in a VM
should be attributable.

### Theme

Nightfox (Duskfox dark, Dawnfox light) across terminals, editors, CLI
tools, and agent UI. Match new tool config to
<https://github.com/EdenEast/nightfox.nvim> when it supports theming.
