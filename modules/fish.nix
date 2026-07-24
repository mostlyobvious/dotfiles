{
  lib,
  pkgs,
  ...
}:

{
  programs.fish = {
    enable = true;
    shellInit = ''
      set fish_greeting

      if status is-interactive; and type -q devenv
        set --global --export DEVENV_SHELL_TYPE fish
        devenv hook fish | source
      end
    ''
    + lib.optionalString pkgs.stdenv.isDarwin ''
      # nix-darwin wires this into PATH via an /etc/profile hook that fish does
      # not read. Prepend it ourselves so Nix-provided CLI tools win over brew.
      fish_add_path --global --prepend /run/current-system/sw/bin
    '';
  };

  # Config files default to in-store. conf.d is linked per-file so HM-generated
  # conf.d entries don't collide with the directory.
  xdg.configFile."fish/functions".source = ../config/fish/functions;

  xdg.configFile."fish/conf.d/hydro.fish".source = ../config/fish/conf.d/hydro.fish;
  xdg.configFile."fish/conf.d/spring.fish".source = ../config/fish/conf.d/spring.fish;
}
