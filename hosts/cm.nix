{
  arch = "aarch64-darwin";

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

  users = {
    mostlyobvious = {
      admin = true;
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
          my.userEmail = "pawel.pacana@chattermill.io";
          my.logseqGraphs = [ "Documents/CM" ];
        }
      ];
    };
  };
}
