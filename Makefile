HOST  = pro
HMCFG = mostlyobvious
FLAKE = .

# Absolute path: darwin-rebuild lives in the system profile, which is not on
# sudo's secure PATH (nor on the user PATH until the fish path fix activates).
DRB = /run/current-system/sw/bin/darwin-rebuild

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

home: ## VM: home-manager switch (no darwin, no brew)
	home-manager switch --flake $(FLAKE)#$(HMCFG)
.PHONY: home

update: ## Bump flake inputs, then switch (deliberate upgrade)
	nix flake update
	$(MAKE) switch
.PHONY: update

gc: ## Garbage-collect the Nix store
	nix store gc
.PHONY: gc

bootstrap: ## Cold start: install Homebrew (if absent), then first switch
	@test -x /opt/homebrew/bin/brew || \
	  /bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	sudo -H nix run nix-darwin -- switch --flake $(FLAKE)#$(HOST)
.PHONY: bootstrap
