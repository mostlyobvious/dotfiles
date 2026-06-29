# dotfiles

Nix + home-manager managed. Two outputs from one flake, sharing
`modules/home/common.nix`:

- `darwinConfigurations.pro` — macOS host (nix-darwin → home-manager + Homebrew +
  macOS defaults).
- `homeConfigurations.mostlyobvious` — standalone home-manager for VMs (portable
  subset only; no brew, no macOS config).

## Apply (steady state)

```
make switch     # host: darwin-rebuild switch --flake .#pro  (HM + brew + macOS)
make home       # VM:   home-manager switch --flake .#mostlyobvious
make build      # compile the host closure without activating
make update     # nix flake update, then switch
make gc         # nix store gc
```

## Bootstrap (fresh Mac)

Stock macOS only needs `make` (ships with the Xcode Command Line Tools:
`xcode-select --install`).

1. `make bootstrap` — installs Nix (Determinate Systems installer) and Homebrew if
   absent, then runs the first switch via `nix run nix-darwin` (since `darwin-rebuild`
   does not exist yet). This installs `darwin-rebuild`, all packages and dotfiles,
   runs `brew bundle`, and sets fish as the login shell.
2. Open a new terminal (so the freshly installed Nix is on `PATH`).
3. Thereafter: `make switch`.

If the login shell does not change automatically, run once:
`chsh -s $(which fish)`.

In a VM there is no brew step — just `make home`.

## Design

### Two outputs, one shared module

One flake exposes `darwinConfigurations.pro` (nix-darwin → home-manager + Homebrew
+ macOS defaults) and `homeConfigurations.mostlyobvious` (standalone home-manager).
Both import `modules/home/common.nix`.

Declarative Homebrew wants nix-darwin; VM reuse wants plain home-manager. One flake
serves both without forcing brew or darwin into the VM. Host-only concerns stay in
the darwin output, so the shared module evaluates identically on host and VM.

### Determinate owns Nix

The Determinate installer manages the daemon and `/etc/nix/nix.conf`. nix-darwin runs
with `nix.enable = false` so the two never fight over the daemon or config. Extra Nix
settings go through Determinate's `nix.custom.conf`, not nix-darwin.

### Unstable everywhere

`nixos-unstable` for both outputs, with `home-manager`/`nix-darwin` set to
`follows = "nixpkgs"` so there is a single nixpkgs in the closure. Determinism comes
from `flake.lock`; upgrades are a deliberate `nix flake update`. Same channel host and
VM keeps the shared module evaluating identically.

### Dotfile delivery — raw files first

Rich hand-written config stays as raw files; `programs.*` modules are used only where
they buy real portability (git, fish, fzf, direnv — they erase host-hardcoded paths).

- **Out-of-store** (symlink to the working copy, edits are live, no rebuild):
  `config/nvim/`, fish `functions/` and `conf.d/`. These are what we iterate on.
- **In-store** (copied into the store, read-only, rollback-able): `.gemrc`, `.irbrc`,
  and the host-only `.ssh/config` / `.ideavimrc` / `.hushlogin`.

In-store would cost the edit loop without buying determinism for nvim (its plugins are
pinned by their own lockfile, not Nix), so the things we touch daily stay out-of-store.

### Neovim plugins stay in vim.pack

Native `vim.pack` + `nvim-pack-lock.json` already pin plugins and work in a VM (needs
only `git` + `neovim`). Moving them to `pkgs.vimPlugins` buys no determinism the
lockfile doesn't already give, and nixpkgs lags bleeding-edge plugins. Nix's job for
nvim is just the binary and placing the config tree.

### Ruby — per-project devshells

Each project declares its Ruby via its own `flake.nix` +
`.envrc`; `nix-direnv` wires it on `cd`. The shared module only enables `direnv` +
`nix-direnv`.

### Homebrew — host-only, zap

GUI casks and a few host-only CLI tools (rtl_433, lima, container) that have no portable
VM use. Everything else is Nix or dropped. `cleanup = "zap"` makes the declared lists the
single source of truth; `autoUpdate`/`upgrade` off so a switch is fast and reproducible.
nix-darwin does not install Homebrew — it must already exist (see Bootstrap above).

### VM isolation

Nothing identity-, credential-, or host-bound crosses into the shared layer. SSH
keys/config stay on the host; the VM uses its own. That's why `.ssh/config` and iCloud
history sync live in the darwin layer, not `common.nix`.
