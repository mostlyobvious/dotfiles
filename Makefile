HOST       = pro
HMCFG      = nixden
VM         = nixden
VM_WORKDIR = /tmp/lima-$(VM)/dotfiles
FLAKE      = .

# Absolute path: darwin-rebuild lives in the system profile, which is not on
# sudo's secure PATH (nor on the user PATH until the fish path fix activates).
DRB = /run/current-system/sw/bin/darwin-rebuild

# Absolute path: a freshly installed Nix is not on PATH in this same shell
# (the installer only wires it up for new login sessions).
NIX = /nix/var/nix/profiles/default/bin/nix

# Self-documenting: lists targets annotated with a `## description` comment.
help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | sort \
	  | awk 'BEGIN {FS = ":.*?## "} {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'
.PHONY: help
.DEFAULT_GOAL := help

switch: ## Host: activate config (HM + brew + macOS). Idempotent
	sudo -H $(DRB) switch --flake $(FLAKE)#$(HOST)
.PHONY: switch

build: ## Compile the host closure without activating (safe pre-flight)
	$(DRB) build --flake $(FLAKE)#$(HOST)
.PHONY: build

check: ## Run flake checks for tracked repo Nix files
	nix flake check
.PHONY: check

home: ## VM: sync dotfiles and activate home-manager (VM=... HMCFG=...)
	rsync -a --delete \
	  --exclude .git \
	  --exclude .direnv \
	  --exclude result \
	  ./ /tmp/lima-$(VM)/dotfiles/
	limactl shell --workdir=$(VM_WORKDIR) $(VM) -- \
	  bash -lc 'nix build .#homeConfigurations.$(HMCFG).activationPackage && ./result/activate'
.PHONY: home

update: ## Bump flake inputs, then switch (deliberate upgrade)
	nix flake update
	$(MAKE) switch
.PHONY: update

gc: ## Garbage-collect the Nix store
	nix store gc
.PHONY: gc

bootstrap: ## Cold start: install Nix + Homebrew (if absent), then first switch
	@test -x $(NIX) || \
	  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
	    | sh -s -- install --determinate --no-confirm
	@test -x /opt/homebrew/bin/brew || \
	  /bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	sudo -H $(NIX) run nix-darwin -- switch --flake $(FLAKE)#$(HOST)
.PHONY: bootstrap
