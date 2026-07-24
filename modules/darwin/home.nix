{ pkgs, ... }:

{
  # Shared darwin home layer — macOS-only tools (iCloud, SSH host identity).
  # home-manager modules, NOT nix-darwin system modules; those are aggregated by
  # ./default.nix. Wired into home-manager.users via flake.nix, never on the VM.
  imports = [
    ./ssh.nix
    ./ghostty.nix
    ./zed.nix
    ./logseq.nix
    ./fonts.nix
    ./macos-defaults.nix
  ];

  home.packages = with pkgs; [
    lima
    rtl_433
  ];
}
