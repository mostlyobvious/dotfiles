{ config, pkgs, ... }:

{
  # Pi the coding agent, from nixpkgs; shared module so both host and VM get it.
  # The module wraps pi with Node/npm for package installs without adding Node to
  # the user's global package set.
  programs.pi-coding-agent = {
    enable = true;
    extraPackages = [ pkgs.nodejs ];
  };

  # Out-of-store: pi rewrites settings.json at runtime, so edits land straight in
  # the working copy. The rest of ~/.pi (auth.json, trust.json, npm/) is runtime
  # state and secrets, left unmanaged.
  home.file.".pi/agent/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesDir}/config/pi/settings.json";

  # Live system theme support: pi hot-reloads the active custom theme file, so the
  # watcher rewrites ~/.pi/agent/themes/rose-pine.json when macOS flips
  # light/dark mode. Keep the rewritten theme unmanaged runtime state so system
  # appearance changes do not dirty the dotfiles working tree.
  home.file.".pi/agent/themes/.keep".text = "";
  home.file.".pi/agent/theme-sources/rose-pine-dark.json".source =
    ../../config/pi/theme-sources/rose-pine-dark.json;
  home.file.".pi/agent/theme-sources/rose-pine-light.json".source =
    ../../config/pi/theme-sources/rose-pine-light.json;
  home.file.".pi/agent/bin/pi-system-theme-watch" = {
    source = ../../config/pi/bin/pi-system-theme-watch;
    executable = true;
  };
}
