{
  config,
  lib,
  pkgs,
  ...
}:

let
  # writeShellApplication shellchecks both scripts at build time and pins jq.
  statusline = pkgs.writeShellApplication {
    name = "statusline-command";
    runtimeInputs = [ pkgs.jq ];
    text = builtins.readFile ./claude/statusline-command.sh;
  };
  blockDangerousGit = pkgs.writeShellApplication {
    name = "block-dangerous-git";
    runtimeInputs = [ pkgs.jq ];
    text = builtins.readFile ./claude/block-dangerous-git.sh;
  };
in
{
  imports = [ ./agents.nix ];

  # Claude Code CLI from nixpkgs; shared module so both host and VM can run it.
  programs.claude-code.enable = true;

  # Out-of-store: Claude Code rewrites settings.json at runtime, so edits land
  # straight in the working copy. The rest of ~/.claude is runtime state, unmanaged.
  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesDir}/config/claude/settings.json";

  # Static scripts referenced by settings.json under stable ~/.claude paths.
  home.file.".claude/statusline-command.sh".source = lib.getExe statusline;
  home.file.".claude/hooks/block-dangerous-git.sh".source = lib.getExe blockDangerousGit;
}
