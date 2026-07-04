{ pkgs, ... }:

{
  # Host-only home-manager modules — config for macOS-only tools (casks, iCloud,
  # SSH host identity). These are home-manager, NOT nix-darwin system modules;
  # the system modules are aggregated by ./default.nix. Wired into the host's
  # home-manager.users via flake.nix, never loaded on the VM.
  imports = [
    ./history.nix
    ./ssh.nix
    ./ghostty.nix
    ./zed.nix
    ./github-runner-mrs.nix
  ];

  home.packages = with pkgs; [
    lima
    rtl_433
  ];
}
