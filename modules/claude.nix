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
  mrDescribe = pkgs.writeShellApplication {
    name = "mr-describe";
    runtimeInputs = [
      pkgs.diffutils
      pkgs.glab
      pkgs.jq
    ];
    text = builtins.readFile ./claude/mr-describe.sh;
  };
  agentGuard = pkgs.callPackage ../packages/agent-guard.nix { };
  agentWorktree = pkgs.callPackage ../packages/agent-worktree.nix { };
  mcpServers = config.my.claudeMcpServers;
  mcpServerNames = builtins.attrNames mcpServers;
  mcpConfig = (pkgs.formats.json { }).generate "managed-claude-mcp.json" {
    inherit mcpServers;
  };
  # Claude Code writes /model and /config choices into this file, so it
  # stays the account's own; policy lives in modules/claude-managed.nix.
  seedSettings = (pkgs.formats.json { }).generate "claude-seed-settings.json" {
    permissions.defaultMode = "auto";
    model = "fable";
    modelSettings."claude-fable-5-1".effortLevel = "xhigh";
    theme = "auto";
    skipWorkflowUsageWarning = true;
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

    # Static scripts referenced by the managed settings under stable ~/.claude paths.
    home.file.".claude/statusline-command.sh".source = lib.getExe statusline;
    home.file.".claude/hooks/agent-guard".source = lib.getExe agentGuard;
    home.file.".claude/hooks/agent-worktree".source = lib.getExe agentWorktree;

    home.packages = [ mrDescribe ];

    home.activation.seedClaudeSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      settings="$HOME/.claude/settings.json"
      if [ ! -e "$settings" ]; then
        run mkdir -p "$HOME/.claude"
        run install -m 0644 ${seedSettings} "$settings"
      fi
    '';

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
