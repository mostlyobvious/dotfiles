module AgentHooks
  module Guard
    BLOCKED_MESSAGE = "BLOCKED: create worktrees with EnterWorktree (name), which runs the WorktreeCreate hook and moves this session into the new worktree.\n"
    WORKTREE_ADD = /(?:\A|[&|;(]\s*)git(?:\s+-C\s+\S+)?\s+worktree\s+add(?:\s|\z)/
    CHANGE_DIRECTORY = /(?:\A|[&|;(]\s*)cd\s+["']?([^\s"';&|)]+)/

    def self.call(event, home)
      command = event.fetch("tool_input").fetch("command")

      return [2, BLOCKED_MESSAGE] if WORKTREE_ADD.match?(command)

      target = worktree_target(command, home)
      if target
        cwd = event.fetch("cwd")
        return [0, ""] if cwd == target || cwd.start_with?("#{target}/")

        return [2, "BLOCKED: this session runs in #{cwd}. Call EnterWorktree with path #{target} so every command starts there, then rerun without the cd.\n"]
      end

      [0, ""]
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
    private_class_method :worktree_target
  end
end
