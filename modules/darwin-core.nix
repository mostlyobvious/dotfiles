{
  username,
  hostname,
  ...
}:

{
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Uniform across macOS's three host identifiers: ComputerName (Sharing UI),
  # HostName (scutil/shell), LocalHostName (Bonjour .local).
  networking.computerName = hostname;
  networking.hostName = hostname;
  networking.localHostName = hostname;

  # Determinate owns the Nix daemon and /etc/nix/nix.conf.
  nix.enable = false;

  # Required by nix-darwin for user-scoped options (homebrew, defaults).
  system.primaryUser = username;
  system.stateVersion = 6;

  # The login shell is set with dscl in account.nix's activation script;
  # users.users.*.shell would only apply to knownUsers-managed accounts.
  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };
}
