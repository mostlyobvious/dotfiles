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
  enforceChangeWriting = pkgs.writeShellApplication {
    name = "enforce-change-writing";
    runtimeInputs = [ pkgs.jq ];
    text = builtins.readFile ./claude/enforce-change-writing.sh;
  };
  blockAnthropicAttribution = pkgs.writeShellApplication {
    name = "block-anthropic-attribution";
    runtimeInputs = [ pkgs.jq ];
    text = builtins.readFile ./claude/block-anthropic-attribution.sh;
  };
  remindMrDescription = pkgs.writeShellApplication {
    name = "remind-mr-description";
    runtimeInputs = [ pkgs.jq ];
    text = builtins.readFile ./claude/remind-mr-description.sh;
  };
  worktreeCreate = pkgs.writeShellApplication {
    name = "worktree-create";
    runtimeInputs = [
      pkgs.jq
      pkgs.git
      pkgs.coreutils
      pkgs.devenv
    ];
    text = builtins.readFile ./claude/worktree-create.sh;
  };
  stopDevenv = pkgs.writeShellApplication {
    name = "stop-devenv";
    runtimeInputs = [
      pkgs.devenv
      pkgs.git
      pkgs.jq
    ];
    text = builtins.readFile ./claude/stop-devenv.sh;
  };
  mcpServers = config.my.claudeMcpServers;
  mcpServerNames = builtins.attrNames mcpServers;
  mcpConfig = (pkgs.formats.json { }).generate "managed-claude-mcp.json" {
    inherit mcpServers;
  };
in
{
  imports = [ ./agents.nix ];

  options.my.claudeMcpServers = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = { };
    description = "MCP servers managed in Claude Code's user scope";
  };

  config = {
    programs.claude-code = {
      enable = true;
      package = pkgs.llm-agents.claude-code;
    };

    # Out-of-store: Claude Code rewrites settings.json at runtime, so edits land
    # straight in the working copy. The rest of ~/.claude is runtime state, unmanaged.
    home.file.".claude/settings.json".source =
      config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesDir}/config/claude/settings.json";

    # Static scripts referenced by settings.json under stable ~/.claude paths.
    home.file.".claude/statusline-command.sh".source = lib.getExe statusline;
    home.file.".claude/hooks/block-dangerous-git.sh".source = lib.getExe blockDangerousGit;
    home.file.".claude/hooks/enforce-change-writing.sh".source = lib.getExe enforceChangeWriting;
    home.file.".claude/hooks/block-anthropic-attribution.sh".source =
      lib.getExe blockAnthropicAttribution;
    home.file.".claude/hooks/remind-mr-description.sh".source = lib.getExe remindMrDescription;
    home.file.".claude/hooks/worktree-create.sh".source = lib.getExe worktreeCreate;
    home.file.".claude/hooks/stop-devenv.sh".source = lib.getExe stopDevenv;

    home.activation.managedClaudeMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      state_dir=${lib.escapeShellArg config.xdg.stateHome}/claude-code
      state_file="$state_dir/managed-mcp-servers"
      mkdir -p "$state_dir"

      if [ -f "$state_file" ]; then
        while IFS= read -r server; do
          [ -z "$server" ] || ${lib.getExe config.programs.claude-code.package} mcp remove --scope user "$server" >/dev/null 2>&1 || true
        done < "$state_file"
      fi

      next_state="$state_file.next"
      : > "$next_state"
      for server in ${lib.escapeShellArgs mcpServerNames}; do
        entry="$(${lib.getExe pkgs.jq} --compact-output --arg server "$server" '.mcpServers[$server]' ${mcpConfig})"
        ${lib.getExe config.programs.claude-code.package} mcp remove --scope user "$server" >/dev/null 2>&1 || true
        ${lib.getExe config.programs.claude-code.package} mcp add-json --scope user "$server" "$entry" >/dev/null
        printf '%s\n' "$server" >> "$next_state"
      done
      mv "$next_state" "$state_file"
    '';
  };
}
