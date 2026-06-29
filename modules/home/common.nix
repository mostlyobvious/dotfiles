{
  config,
  lib,
  pkgs,
  username,
  ...
}:

{
  imports = [
    ./git.nix
    ./fish.nix
    ./neovim.nix
    ./ruby.nix
    ./claude.nix
    ./zed.nix
    ./eza.nix
  ];

  # Working-copy path for out-of-store symlinks. Override if the repo lives elsewhere.
  options.my.dotfilesDir = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/Code/dotfiles";
    description = "Absolute path to the dotfiles working copy.";
  };

  config = {
    home.username = username;
    home.homeDirectory = lib.mkDefault (
      if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}"
    );
    home.stateVersion = "25.05";

    home.packages = with pkgs; [
      fd
      gh
      jq
      ripgrep
      stylua
      lua-language-server
    ];

    programs.home-manager.enable = true;

    # Empty file; its mere existence suppresses the login banner.
    home.file.".hushlogin".text = "";

    # Skip the home-manager manpage: its options.json embeds the nixpkgs source
    # path without context (a Nix warning), and we read options online.
    manual.manpages.enable = false;

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    programs.fzf.enable = true;
  };
}
