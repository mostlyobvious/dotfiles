{
  arch = "aarch64-darwin";

  # nix-darwin system module for this machine
  system = {
    imports = [
      ../modules/darwin-core.nix
      ../modules/system.nix
      ../modules/sudo.nix
      ../modules/sshd.nix
      ../modules/homebrew.nix
      ../modules/account.nix
    ];
  };

  # every account on this machine; the invoking admin activates directly,
  # every other account via sudo -u
  users = {
    mostlyobvious = {
      admin = true;
      key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFai8QY2psbXCIconVn7fLRxtWmIpsasY03qgBVA8NdS mostlyobvious@pro"; # authorized on non-admin accounts
      modules = [
        ../modules/core.nix
        ../modules/cli.nix
        ../modules/git.nix
        ../modules/fish.nix
        ../modules/neovim.nix
        ../modules/ruby.nix
        ../modules/claude.nix
        ../modules/pi.nix
        ../modules/eza.nix
        ../modules/skills.nix
        ../modules/ghostty.nix
        ../modules/zed.nix
        ../modules/ssh.nix
        ../modules/fonts.nix
        ../modules/logseq.nix
        ../modules/macos-defaults.nix
        ../modules/history.nix # iCloud-backed; this account only
        (
          { pkgs, ... }:
          {
            home.packages = [
              pkgs.lima
              pkgs.rtl_433
            ]; # runs the VMs; radio tinkering
            my.logseqGraphs = [
              "Notes/mostlyobvious"
              "Notes/hraba.gs"
            ];
          }
        )
      ];
    };

    cm = {
      # admin defaults false; no key — reached only via sudo -u from an admin
      modules = [
        ../modules/core.nix
        ../modules/cli.nix
        ../modules/git.nix
        ../modules/fish.nix
        ../modules/neovim.nix
        ../modules/ruby.nix
        ../modules/claude.nix
        ../modules/pi.nix
        ../modules/eza.nix
        ../modules/skills.nix
        ../modules/ghostty.nix
        ../modules/zed.nix
        ../modules/ssh.nix
        ../modules/fonts.nix
        ../modules/logseq.nix
        ../modules/macos-defaults.nix
        ../modules/kubernetes.nix
        ../modules/vault.nix
        ../modules/redocly.nix
        {
          my.dotfilesDir = "/Users/cm/dotfiles";
          my.signingKey = "/Users/cm/.ssh/id_ed25519.pub";
          my.userEmail = "pawel.pacana@chattermill.io";
          my.logseqGraphs = [ "Documents/CM" ];
        }
      ];
    };
  };

  # each VM is a single-user linux guest; its account is declared by its nixos config
  vms = {
    nixden = {
      arch = "aarch64-linux";
      user = "mostlyobvious";
      system = ../vms/nixden/configuration.nix;
      home = [
        ../modules/core.nix
        ../modules/cli.nix
        ../modules/git.nix
        ../modules/fish.nix
        ../modules/neovim.nix
        ../modules/ruby.nix
        ../modules/claude.nix
        ../modules/pi.nix
        ../modules/eza.nix
        ../modules/skills.nix
        {
          home.homeDirectory = "/home/mostlyobvious.guest";
          my.dotfilesDir = "/mnt/dotfiles"; # the read-only lima mount
          programs.zed-editor = {
            enable = true;
            installRemoteServer = true;
          };
        }
      ];
    };
  };
}
