{ config, pkgs, ... }:

{
  programs.pi-coding-agent = {
    enable = true;
    extraPackages = [ pkgs.nodejs ];
  };

  home.file.".pi/agent/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesDir}/config/pi/settings.json";

  home.file.".pi/agent/AGENTS.md".source = ../../config/agents/AGENTS.md;
}
