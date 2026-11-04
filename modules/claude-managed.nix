{ lib, pkgs, ... }:

let
  guard = {
    type = "command";
    command = "~/.claude/hooks/agent-guard";
  };
  worktree = {
    type = "command";
    command = "~/.claude/hooks/agent-worktree";
  };
  settings = (pkgs.formats.json { }).generate "claude-managed-settings.json" {
    attribution = {
      commit = "";
      pr = "";
    };
    permissions.allow = [ "Bash(glab mr update *)" ];
    hooks = {
      PreToolUse = [
        {
          matcher = "Bash|Artifact|mcp__claude_ai_Linear__.*";
          hooks = [ (guard // { onFailure = "block"; }) ];
        }
      ];
      WorktreeCreate = [ { hooks = [ worktree ]; } ];
      PostToolUse = [
        {
          matcher = "Bash";
          hooks = [ guard ];
        }
        {
          matcher = "Write|Edit";
          hooks = [ guard ];
        }
        { hooks = [ worktree ]; }
      ];
      SessionStart = [ { hooks = [ worktree ]; } ];
      UserPromptSubmit = [ { hooks = [ worktree ]; } ];
      SessionEnd = [ { hooks = [ (worktree // { timeout = 10; }) ]; } ];
    };
    statusLine = {
      type = "command";
      command = "~/.claude/statusline-command.sh";
    };
    enabledPlugins = {
      "ruby-lsp@claude-plugins-official" = true;
      "pyright-lsp@claude-plugins-official" = true;
      "lua-lsp@claude-plugins-official" = true;
    };
    feedbackDrafts = "off";
    awaySummaryEnabled = false;
    autoMemoryEnabled = false;
    preferredNotifChannel = "notifications_disabled";
  };
in
{
  # Managed settings outrank every other settings file, so no project or
  # local file can switch the hooks off. The hook paths are the stable
  # per-account links that modules/claude.nix creates.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    /usr/bin/install -d -m 0755 "/Library/Application Support/ClaudeCode"
    /usr/bin/install -m 0644 ${settings} "/Library/Application Support/ClaudeCode/managed-settings.json"
  '';
}
