# dotfiles

Nix + home-manager managed. One flake defines the macOS host, Linux VM homes,
checks, dev shell, and operational apps.

Important outputs:

- `darwinConfigurations.pro` — macOS host (nix-darwin → home-manager +
  Homebrew + macOS defaults).
- `homeConfigurations.mostlyobvious` — standalone portable home-manager profile.
- `homeConfigurations.nixden` — Lima VM home-manager profile.
- `apps.aarch64-darwin.{bootstrap,switch,update,home}` — operational commands.

## Apply

```sh
nix run .#switch   # host: activate .#pro  (HM + brew + macOS)
nix run .#home     # VM: sync repo into Lima and activate .#homeConfigurations.nixden
nix run .#update   # nix flake update, then switch
nix flake check    # format/dead-code checks + Darwin system build
```

`HOST`, `VM`, and `HMCFG` can override the defaults:

```sh
HOST=pro nix run .#switch
VM=nixden HMCFG=nixden nix run .#home
```

## Bootstrap fresh Mac

Stock macOS only needs `make` after the Xcode Command Line Tools are available:

```sh
xcode-select --install
make
```

`make` is intentionally only a pre-Nix bootstrap shim. It installs Nix with the
Determinate Systems installer if needed, then delegates to `nix run .#bootstrap`.
The flake app installs Homebrew if absent and runs the first nix-darwin switch.

Open a new terminal afterwards so the freshly installed tools are on `PATH`.
Thereafter use the flake apps above.

If the login shell does not change automatically, run once:

```sh
chsh -s $(which fish)
```

## Design

### One flake, shared home module

The flake exposes `darwinConfigurations.pro` for the Mac and standalone
home-manager configurations for portable Linux use. Both paths import
`modules/home/common.nix`.

Declarative Homebrew wants nix-darwin; VM reuse wants plain home-manager. One
flake serves both without forcing brew or Darwin into the VM. Host-only concerns
stay in the Darwin output, so the shared module evaluates identically on host and
VM.

### Determinate owns Nix

The Determinate installer manages the daemon and `/etc/nix/nix.conf`. nix-darwin
runs with `nix.enable = false` so the two never fight over the daemon or config.
Extra Nix settings go through Determinate's `nix.custom.conf`, not nix-darwin.

### Unstable everywhere

`nixos-unstable` for all outputs, with `home-manager`/`nix-darwin` set to
`follows = "nixpkgs"` so there is a single nixpkgs in the closure. Determinism
comes from `flake.lock`; upgrades are a deliberate `nix run .#update`. Same
channel host and VM keeps the shared module evaluating identically.

### Dotfile delivery — raw files first

Rich hand-written config stays as raw files; `programs.*` modules are used only
where they buy real portability (git, fish, fzf, direnv — they erase
host-hardcoded paths).

- **Out-of-store** (symlink to the working copy, edits are live, no rebuild):
  `config/nvim/`, fish `functions/` and `conf.d/`. These are what we iterate on.
- **In-store** (copied into the store, read-only, rollback-able): `.gemrc`,
  `.irbrc`, and the host-only `.ssh/config` / `.ideavimrc` / `.hushlogin`.

In-store would cost the edit loop without buying determinism for nvim (its
plugins are pinned by their own lockfile, not Nix), so the things we touch daily
stay out-of-store.

### Neovim plugins stay in vim.pack

Native `vim.pack` + `nvim-pack-lock.json` already pin plugins and work in a VM
(needs only `git` + `neovim`). Moving them to `pkgs.vimPlugins` buys no
determinism the lockfile doesn't already give, and nixpkgs lags bleeding-edge
plugins. Nix's job for nvim is just the binary and placing the config tree.

### Ruby — per-project devshells

Each project declares its Ruby via its own `flake.nix` + `.envrc`; `nix-direnv`
wires it on `cd`. The shared module only enables `direnv` + `nix-direnv`.

### Homebrew — host-only, zap

GUI casks and a few host-only CLI tools (rtl_433, lima, container) that have no
portable VM use. Everything else is Nix or dropped. `cleanup = "zap"` makes the
declared lists the single source of truth; `autoUpdate`/`upgrade` off so a switch
is fast and reproducible. nix-darwin does not install Homebrew — it must already
exist, except during bootstrap where `nix run .#bootstrap` installs it if absent.

### VM isolation

Nothing identity-, credential-, or host-bound crosses into the shared layer. SSH
keys/config stay on the host; the VM uses its own. That's why `.ssh/config` and
iCloud history sync live in the Darwin layer, not `common.nix`.
