# dotfiles

Nix-managed: nix-darwin for macOS system state and home-manager for every
account. This flake owns machine orchestration and pins every input in
`flake.lock`.

## Layout

- `hosts/`: the root of the tree, with one file per machine containing
  its system modules, Homebrew casks, and accounts.
- `lib/`: turns the host tree into flake outputs through `mk-darwin.nix`,
  `mk-home.nix`, and `apps.nix`.
- `modules/`: nix-darwin and home-manager modules selected by each host
  and account in `hosts/`; `modules/profiles/` groups the ones every Mac
  gets.
- `config/`: raw dotfiles delivered by the modules.
- `skills/`: agent skills installed for Claude Code and pi.
- `agent-hooks/` and `packages/`: the Ruby source and Nix packages for the
  `agent-guard` and `agent-worktree` hooks.

Outputs mirror the tree: `darwinConfigurations.<host>` and
`homeConfigurations."<host>-<user>"`. `make check` builds each of them and
also runs nixfmt, deadnix, the agent-hooks tests, and the `change-writing`
Vale checks.

## Apply

```sh
make         # = nix run .#switch
make check   # = nix flake check
```

`switch` derives the host from `scutil --get LocalHostName` and converges
everything in order: the nix-darwin system, then each account's home (the
invoking user directly, other accounts via `sudo -u`).

## Bootstrap fresh Mac

```sh
make bootstrap HOST=<host>   # one of hosts/
```

A pre-Nix shim only: when the Xcode Command Line Tools are missing, it
starts their installer and exits; run it again once they finish. It then
installs Determinate Nix and delegates to
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

`hosts/cm.nix` keeps the work machine in the same host tree and imports the
private Chattermill Home Manager and Darwin modules for work requirements.
The `chattermill` repository remains a separate pinned flake input. Evaluating
or switching the `cm` configuration requires SSH access to that repository.

### Unstable everywhere

All outputs use `nixos-unstable`. `home-manager` and `nix-darwin` follow
the root nixpkgs, so shared modules evaluate against the same packages on
every host and VM. `flake.lock` provides determinism; `nix flake update`
performs deliberate upgrades.

### Dotfile delivery defaults to the Nix store

Config lives inline in `modules/` as program options or Nix strings. The
Nix store delivers read-only files that match the flake revision and can
be rolled back. `config/` holds only exceptions where an application owns
the file, rewrites it through its UI, or needs a live edit loop, such as
Neovim, Zed, and agent settings.

### Neovim plugins stay in vim.pack

`vim.pack` + `nvim-pack-lock.json` already pin plugins and work anywhere
with git + neovim. Nix's job for nvim is the binary and the config tree.

### Ruby uses per-project development environments

Projects declare Ruby in their own `devenv.nix`, which `direnv` loads on
entry; these dotfiles install no global Ruby. `modules/ruby.nix` holds
only gem and IRB settings.

### Homebrew manages GUI applications

Casks and MAS apps are declared per host in `hosts/`; Nix provides CLI
tooling except for a few host-only tools. `cleanup = "zap"` makes the
declared lists the single source of truth. Automatic updates and upgrades
remain disabled to keep switching fast. nix-darwin manages an existing
Homebrew installation; bootstrap and switch install Homebrew when absent.

Apple's `container` CLI is installed from its signed package, not the
Homebrew formula. The formula's binaries are ad hoc signed; the signed
package places the CLI at `/usr/local/bin/container`. `make switch`
installs the pinned 1.6.0 package when the CLI is missing or a different
version is installed, stopping any running container services first. The
package requires macOS 26 or later. Each account's launch agent starts
the container service from the package path at login. See
[Apple's releases](https://github.com/apple/container/releases).

### Theme

Nightfox (Duskfox dark, Dawnfox light) across terminals, editors, CLI
tools, and agent UI. Match new tool config to
<https://github.com/EdenEast/nightfox.nvim> when it supports theming.

## Linux VMs

A host can declare Lima guests under `vms`; none is enabled now. Each guest
lives in `vms/` with its NixOS configuration and `lima.yaml`, and adds
`nixosConfigurations.<vm>` and `homeConfigurations."<vm>"` outputs.
`switch` starts each declared guest after the accounts and rebuilds it from
the read-only `/mnt/dotfiles` mount.

Nothing credential- or host-bound crosses into modules shared with VMs.
SSH keys and config stay on the host; the VM uses its own. Commit
identity (name, email) does cross, deliberately: work done in a VM
should be attributable.
