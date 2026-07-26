# Multi-host refactor

The flake is restructured around the host tree: `hosts/<host>.nix` is the root
for a machine (its `arch`, `system`, `users`, and `vms`), `lib/` walks the tree
to derive every darwin/home/nixos target and the two commands (`bootstrap
<host>`, `switch`), and `modules/` is one flat file-per-feature directory.

## Assumptions (stated, not enforced)

- Hostnames are unique across the whole fleet, VMs included. A VM lives under
  its host in the tree, so this is naturally true unless two hosts name a VM
  the same; the derived output names would then collide.
- `pro`'s `cm` account survives the arrival of host `cm` until work migrates;
  removing it is deleting one entry from `hosts/pro.nix`.

## Stage 5 — Bring up host `cm`

- `hosts/cm.nix` has a single `mostlyobvious` account with `admin = true`,
  mirroring `pro`'s `cm` account (work email, `Documents/CM` graph, work tool
  files); no non-admin accounts, no VMs yet.
- On the new machine: install nix + homebrew, then `nix run .#bootstrap -- cm`.
- `darwinConfigurations.cm` and `homeConfigurations.cm-mostlyobvious` are in
  `checks` via the host tree walk.
- With no non-admin accounts, `account.nix` authorizes nothing; the admin's
  own `key` is irrelevant until this host gains a non-admin account.

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
