{
  nix-darwin,
  determinate,
  allowUnfreePred,
  lib,
}:

# Builds one host's nix-darwin system from its tree entry (arch, system
# module, users map). Every account's home is standalone (see mk-home.nix);
# this only wires the OS-level system + account provisioning.
hostName: host:
let
  admins = lib.filterAttrs (_: u: u.admin or false) host.users;
  adminNames = builtins.attrNames admins;

  # system.primaryUser is the sole admin automatically; a multi-admin host
  # must mark exactly one account primary = true.
  primaryUser =
    if adminNames == [ ] then
      throw "host ${hostName} has no admin account"
    else if builtins.length adminNames == 1 then
      builtins.head adminNames
    else
      let
        primaries = builtins.filter (name: admins.${name}.primary or false) adminNames;
      in
      assert lib.assertMsg (
        builtins.length primaries == 1
      ) "host ${hostName}: multi-admin hosts must mark exactly one account primary = true";
      builtins.head primaries;

  primaryAccount = host.users.${primaryUser};

  nonAdminAccounts = builtins.attrNames (lib.filterAttrs (_: u: !(u.admin or false)) host.users);

  adminKeys = builtins.filter (k: k != null) (map (name: admins.${name}.key or null) adminNames);
in
nix-darwin.lib.darwinSystem {
  system = host.arch;
  specialArgs = {
    username = primaryUser;
    hostname = hostName;
    inherit nonAdminAccounts adminKeys;
    allAccounts = builtins.attrNames host.users;
    homebrewCasks = primaryAccount.homebrew.casks or [ ];
    homebrewMasApps = primaryAccount.homebrew.masApps or { };
  };
  modules = [
    determinate.darwinModules.default
    { nixpkgs.config.allowUnfreePredicate = allowUnfreePred; }
    host.system
  ];
}
