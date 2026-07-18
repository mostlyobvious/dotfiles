{ pkgs, ... }:

{
  # Shared darwin home layer — macOS-only tools (iCloud, SSH host identity).
  # home-manager modules, NOT nix-darwin system modules; those are aggregated by
  # ./default.nix. Wired into home-manager.users via flake.nix, never on the VM.
  # Account-specific modules (github-runner-mrs) are imported per-user there too.
  imports = [
    ./ssh.nix
    ./ghostty.nix
    ./zed.nix
    ./fonts.nix
    ./macos-defaults.nix
  ];

  home.packages = with pkgs; [
    lima
    rtl_433
  ];
}
