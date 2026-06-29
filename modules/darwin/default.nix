{ pkgs, username, ... }:

{
  imports = [
    ./homebrew.nix
    ./system.nix
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";

  # Uniform across macOS's three host identifiers: ComputerName (Sharing UI),
  # HostName (scutil/shell), LocalHostName (Bonjour .local).
  networking.computerName = "pro";
  networking.hostName = "pro";
  networking.localHostName = "pro";

  # Determinate owns the Nix daemon and /etc/nix/nix.conf.
  nix.enable = false;

  # Required by nix-darwin for user-scoped options (homebrew, defaults).
  system.primaryUser = username;
  system.stateVersion = 6;

  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
    shell = pkgs.fish;
  };
}
