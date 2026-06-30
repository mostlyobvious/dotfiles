NIX = /nix/var/nix/profiles/default/bin/nix

.DEFAULT_GOAL := bootstrap

bootstrap:
	@test -x $(NIX) || \
	  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
	    | sh -s -- install --determinate --no-confirm
	$(NIX) run .#bootstrap

.PHONY: bootstrap
