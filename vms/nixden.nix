{
  arch = "aarch64-linux";
  user = "mostlyobvious";
  system = ./nixden/configuration.nix;
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
}
