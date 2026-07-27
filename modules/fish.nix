{
  lib,
  pkgs,
  ...
}:

{
  programs.fish = {
    enable = true;
    shellAliases.less = "less -R";

    # Upstream hydro prompt; local deviations go through its public
    # variables (see conf.d/hydro-theme.fish below), no forked functions.
    plugins = [
      {
        name = "hydro";
        inherit (pkgs.fishPlugins.hydro) src;
      }
    ];

    shellInit = ''
      set fish_greeting
    ''
    + lib.optionalString pkgs.stdenv.isDarwin ''
      # Pinned copy of `brew shellenv fish` to skip exec'ing brew per shell;
      # re-sync if brew's shellenv output changes.
      set --global --export HOMEBREW_PREFIX /opt/homebrew
      set --global --export HOMEBREW_CELLAR /opt/homebrew/Cellar
      set --global --export HOMEBREW_REPOSITORY /opt/homebrew
      fish_add_path --global --move --path /opt/homebrew/bin /opt/homebrew/sbin
      if test -n "$MANPATH[1]"; set --global --export MANPATH ''' $MANPATH; end
      if not contains /opt/homebrew/share/info $INFOPATH
        set --global --export INFOPATH /opt/homebrew/share/info $INFOPATH
      end
      if test -d /opt/homebrew/share/fish/completions
        set -p fish_complete_path /opt/homebrew/share/fish/completions
      end
      if test -d /opt/homebrew/share/fish/vendor_completions.d
        set -p fish_complete_path /opt/homebrew/share/fish/vendor_completions.d
      end

      # nix-darwin wires this into PATH via an /etc/profile hook that fish does
      # not read. Prepend it after brew so Nix-provided CLI tools win.
      fish_add_path --global --prepend /run/current-system/sw/bin
    '';
  };

  # Config files default to in-store. conf.d is linked per-file so HM-generated
  # conf.d entries don't collide with the directory.
  xdg.configFile."fish/functions".source = ../config/fish/functions;

  xdg.configFile."fish/conf.d/spring.fish".source = ../config/fish/conf.d/spring.fish;

  # Named to sort before plugin-hydro.fish: hydro bakes hydro_symbol_prompt
  # into _hydro_status as its conf.d loads, so the overrides must exist first.
  xdg.configFile."fish/conf.d/hydro-theme.fish".text = ''
    set --global hydro_symbol_prompt \$
    set --global hydro_symbol_git_dirty ' •'

    if set --query SSH_CONNECTION; or set --query SSH_TTY
        set --global hydro_symbol_start (prompt_hostname)' '
    end
  '';
}
