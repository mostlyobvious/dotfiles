{ config, lib, pkgs, username, ... }:

{
  programs.fish = {
    enable = true;
    shellInit = ''
      set fish_greeting
    '' + lib.optionalString pkgs.stdenv.isDarwin ''
      /opt/homebrew/bin/brew shellenv | source
      # nix-darwin wires these into PATH via /etc/profile hooks that fish does
      # not read. Prepend them ourselves so Nix-provided CLI tools win over brew.
      fish_add_path --global --prepend /run/current-system/sw/bin /etc/profiles/per-user/${username}/bin
    '';
  };

  # conf.d linked per-file so HM-generated conf.d entries don't collide with the symlink.
  xdg.configFile."fish/functions".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesDir}/config/fish/functions";

  xdg.configFile."fish/conf.d/editor.fish".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesDir}/config/fish/conf.d/editor.fish";
  xdg.configFile."fish/conf.d/hydro.fish".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesDir}/config/fish/conf.d/hydro.fish";
  xdg.configFile."fish/conf.d/spring.fish".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesDir}/config/fish/conf.d/spring.fish";
}
