{ config, ... }:

{
  # Out-of-store: Zed rewrites settings.json at runtime, so edits land straight
  # in the working copy. Zed itself is installed as a cask, not by Nix.
  xdg.configFile."zed/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesDir}/config/zed/settings.json";
}
