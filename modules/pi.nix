{ config, pkgs, ... }:

let
  agentGuard = pkgs.callPackage ../packages/agent-guard.nix { };
  agentWorktree = pkgs.callPackage ../packages/agent-worktree.nix { };
in
{
  imports = [ ./agents.nix ];

  programs.pi-coding-agent = {
    enable = true;
    package = pkgs.llm-agents.pi;
    extraPackages = [
      agentGuard
      agentWorktree
      pkgs.nodejs
    ];
  };

  home.file.".pi/agent/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesDir}/config/pi/settings.json";

  home.file.".pi/agent/extensions".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesDir}/config/pi/extensions";
}
