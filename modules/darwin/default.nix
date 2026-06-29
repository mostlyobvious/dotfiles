{ pkgs, username, ... }:

{
  imports = [
    ./homebrew.nix
    ./system.nix
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";

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
