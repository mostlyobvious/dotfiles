{
  lib,
  pkgs,
  username,
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
      # nix-darwin wires these into PATH via /etc/profile hooks that fish does
      # not read. Prepend them ourselves so Nix-provided CLI tools win over brew.
      fish_add_path --global --prepend /run/current-system/sw/bin /etc/profiles/per-user/${username}/bin
    '';
  };

  # Config files default to in-store. conf.d is linked per-file so HM-generated
  # conf.d entries don't collide with the directory.
  xdg.configFile."fish/functions".source = ../../config/fish/functions;

  xdg.configFile."fish/conf.d/hydro.fish".source = ../../config/fish/conf.d/hydro.fish;
  xdg.configFile."fish/conf.d/spring.fish".source = ../../config/fish/conf.d/spring.fish;
}
