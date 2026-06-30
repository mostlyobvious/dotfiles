{ config, pkgs, ... }:

{
  # Claude Code CLI from nixpkgs; shared module so both host and VM can run it.
  home.packages = [ pkgs.claude-code ];

  # Out-of-store: Claude Code rewrites settings.json at runtime, so edits land
  # straight in the working copy. The rest of ~/.claude is runtime state, unmanaged.
  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesDir}/config/claude/settings.json";
}
