module AgentHooks
  module Guard
    BLOCKED_MESSAGE = "BLOCKED: create worktrees with EnterWorktree (name), which runs the WorktreeCreate hook and moves this session into the new worktree.\n"
    SHELL_EDIT_MESSAGE = "edits files through an in-place shell command. Use Edit for existing files or Write for new files and complete rewrites."
    WORKTREE_ADD = /(?:\A|[&|;(]\s*)git(?:\s+-C\s+\S+)?\s+worktree\s+add(?:\s|\z)/
    CHANGE_DIRECTORY = /(?:\A|[&|;(]\s*)cd\s+["']?([^\s"';&|)]+)/
    SED_IN_PLACE = /(?:\A|[&|;(]\s*)sed(?:\s+[^&|;]*)?\s+(?:--in-place(?:=\S*)?|-i\S*)(?:\s|\z)/
    PERL_IN_PLACE = /(?:\A|[&|;(]\s*)perl(?:\s+[^&|;]*)?\s+-[0-9A-Za-z]*i[0-9A-Za-z]*(?:\s|\z)/

    def self.call(event, home)
      command = event.fetch("tool_input").fetch("command")

      return [2, shell_edit_message(command)] if shell_edit?(command)
      return [2, BLOCKED_MESSAGE] if WORKTREE_ADD.match?(command)

      target = worktree_target(command, home)
      if target
        cwd = event.fetch("cwd")
        return [0, ""] if cwd == target || cwd.start_with?("#{target}/")

        return [2, "BLOCKED: this session runs in #{cwd}. Call EnterWorktree with path #{target} so every command starts there, then rerun without the cd.\n"]
      end

      [0, ""]
    end

    def self.shell_edit?(command)
      SED_IN_PLACE.match?(command) || PERL_IN_PLACE.match?(command)
    end

    def self.shell_edit_message(command)
      "BLOCKED: '#{command}' #{SHELL_EDIT_MESSAGE}\n"
    end

    def self.worktree_target(command, home)
      normalized = command.sub("$HOME", home).sub("~/", "#{home}/")
      match = CHANGE_DIRECTORY.match(normalized)
      return unless match

      root = "#{home}/Code/worktrees/"
      path = match[1]
      return unless path.start_with?(root)

      repository, worktree = path[root.length, path.length].split("/")
      return unless worktree

      "#{root}#{repository}/#{worktree}"
    end
    private_class_method :shell_edit?, :shell_edit_message, :worktree_target
  end
end
