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

  # Pi has built-in automatic theme switching for settings of the form
  # "light-theme/dark-theme". Install both variants as normal custom themes so
  # Pi can switch them live from terminal color-scheme notifications.
  home.file.".pi/agent/themes/rose-pine.json" = {
    source = ../../config/pi/theme-sources/rose-pine-dark.json;
    force = true;
  };
  home.file.".pi/agent/themes/rose-pine-dawn.json".source =
    ../../config/pi/theme-sources/rose-pine-light.json;
}
