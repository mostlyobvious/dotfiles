{ config, lib, pkgs, username, ... }:

{
  imports = [
    ./git.nix
    ./fish.nix
    ./neovim.nix
    ./ruby.nix
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
      tree
      stylua
      lua-language-server
    ];

    programs.home-manager.enable = true;

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    programs.fzf.enable = true;
  };
}
