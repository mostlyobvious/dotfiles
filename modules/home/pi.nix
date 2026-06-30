{ config, pkgs, ... }:

{
  # pi the coding agent, from nixpkgs; shared module so both host and VM get it.
  home.packages = [ pkgs.pi-coding-agent ];

  # Out-of-store: pi rewrites settings.json at runtime (e.g. lastChangelogVersion),
  # so edits land straight in the working copy. The rest of ~/.pi (auth.json,
  # trust.json, npm/) is runtime state and secrets, left unmanaged.
  home.file.".pi/agent/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesDir}/config/pi/settings.json";
}
