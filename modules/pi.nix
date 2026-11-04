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
    settings = {
      # pi records the version whose changelog it has shown; pinning it to the
      # installed package keeps startup free of writes to this read-only file.
      lastChangelogVersion = pkgs.llm-agents.pi.version;
      defaultProvider = "openai-codex";
      defaultModel = "gpt-5.6-sol";
      packages = [
        "npm:@juancrg90/nightfox-themes"
        "npm:pi-edit-hooks"
        "npm:pi-acp"
      ];
      extensions = [ "extensions" ];
      theme = "dawnfox";
      quietStartup = true;
    };
  };

  home.file.".pi/agent/extensions".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesDir}/config/pi/extensions";
}
