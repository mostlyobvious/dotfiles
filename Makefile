NIX = /nix/var/nix/profiles/default/bin/nix

.DEFAULT_GOAL := switch

bootstrap:
	@xcode-select -p > /dev/null 2>&1 || \
	  { xcode-select --install; \
	    echo "Command Line Tools installer started; re-run 'make bootstrap' once it finishes." >&2; \
	    exit 1; }
	@test -x $(NIX) || \
	  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
	    | sh -s -- install --determinate --no-confirm
	$(NIX) run .#bootstrap

switch:
	$(NIX) run .#switch

check:
	$(NIX) flake check

.PHONY: bootstrap switch check
