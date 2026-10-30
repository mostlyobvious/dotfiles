module AgentHooks
  module Guard
    BLOCKED_MESSAGE = "BLOCKED: create worktrees through the session host so every command starts in the worktree.\n"
    CHANGE_WRITING_MESSAGE = "BLOCKED: commit messages and MR/PR descriptions require reading and applying change-writing/SKILL.md first.\n"
    ATTRIBUTION_MESSAGE = "BLOCKED: commit messages must not include Anthropic or Claude co-author attribution.\n"
    SHELL_EDIT_MESSAGE = "edits files through an in-place shell command. Use Edit for existing files or Write for new files and complete rewrites."
    MR_REMINDER = "If the pushed branch has an open MR, compare its description with the new diff and propose an update when they disagree (merge-request skill, step 8)."
    REVIEW_REMINDER = "Run the change-writing Review Pass on mr-description.md before presenting it for approval (merge-request skill, step 6)."
    WORKTREE_ADD = /(?:\A|[&|;(]\s*)git(?:\s+-C\s+\S+)?\s+worktree\s+add(?:\s|\z)/
    BROAD_WORKTREE_ADD = /(?:\A|[\s&|;(])git(?:\s+-C\s+\S+)?\s+worktree\s+add/
    CHANGE_DIRECTORY = /(?:\A|[&|;(]\s*)cd\s+["']?([^\s"';&|)]+)/
    INLINE_MR_DESCRIPTION = /(?:\A|[\s&|;(])glab\s+mr\s+(?:create|update)[^&|;]*\s+(?:-d|--description)(?:[\s=]|\z)/
    GIT_PUSH = /(?:\A|[\s&|;(])git(?:\s+-C\s+\S+)?\s+push(?:\s|\z)/
    FORCE_PUSH = /(?:\A|[\s&|;(])git\s+push[^&|;]*\s+(?:-f|--force)(?:[\s=]|\z)/
    PROTECTED_PUSH = /(?:\A|[\s&|;(])git\s+push(?:[^&|;]*[\s:\/])(?:refs\/heads\/)?(?:master|main)(?:[\s&|;:]|\z)/
    DANGEROUS_GIT = [
      [/git reset --hard/, "git reset --hard"],
      [/git clean -fd/, "git clean -fd"],
      [/git clean -f/, "git clean -f"],
      [/git checkout \./, "git checkout \\."],
      [/git restore \./, "git restore \\."],
      [/reset --hard/, "reset --hard"]
    ].freeze
    SED_IN_PLACE = /(?:\A|[&|;(]\s*)sed(?:\s+[^&|;]*)?\s+(?:--in-place(?:=\S*)?|-i\S*)(?:\s|\z)/
    PERL_IN_PLACE = /(?:\A|[&|;(]\s*)perl(?:\s+[^&|;]*)?\s+-[0-9A-Za-z]*i[0-9A-Za-z]*(?:\s|\z)/
    MR_COMMAND = /(?:\A|[\s&|;(])(?:glab\s+mr\s+(?:create|edit|update)|gh\s+pr\s+(?:create|edit))(?:[\s&|;)]|\z)/
    COMMIT_COMMAND = /(?:\A|[\s&|;(])git(?:\s+-C\s+\S+)?\s+commit(?:\s|\z)/
    SHELL_SCRIPT = /[^\s"';|&()]+\.sh/
    COAUTHOR_ATTRIBUTION = /co-authored-by:.*(?:anthropic|claude)|(?:(?:anthropic|claude).*)co-authored-by:/i

    def self.run(event, home)
      if event.fetch("hook_event_name") == "PostToolUse"
        return [0, "", reminder(event)]
      end

      status, message = call(event, home)
      [status, message, nil]
    end

    def self.call(event, home)
      command = event.fetch("tool_input").fetch("command")
      message = dangerous_git_message(command, event, home)
      message ||= shell_edit_message(command)
      message ||= change_writing_message(command, event, home)
      message ||= attribution_message(command)
      return [2, message] if message
      return [2, BLOCKED_MESSAGE] if WORKTREE_ADD.match?(command)

      target = worktree_target(command, home)
      if target
        cwd = event.fetch("cwd")
        return [0, ""] if cwd == target || cwd.start_with?("#{target}/")

        return [2, "BLOCKED: this session runs in #{cwd}. Start or move the session to #{target} so every command starts there, then rerun without the cd.\n"]
      end

      [0, ""]
    end

    def self.reminder(event)
      input = event.fetch("tool_input")
      command = input["command"]
      return reminder_output(MR_REMINDER) if GIT_PUSH.match?(command)

      path = input["file_path"] || input["path"]
      reminder_output(REVIEW_REMINDER) if path && File.basename(path) == "mr-description.md"
    end

    def self.reminder_output(message)
      {"hookSpecificOutput" => {"hookEventName" => "PostToolUse", "additionalContext" => message}}
    end

    def self.dangerous_git_message(command, event, home)
      if BROAD_WORKTREE_ADD.match?(command)
        cwd = event.fetch("cwd")
        dotfiles = "#{home}/Code/dotfiles"
        if cwd == dotfiles || cwd.start_with?("#{dotfiles}/") || /(?:Code|worktrees)\/dotfiles/.match?(command)
          return blocked(command, "adds a worktree to dotfiles, which is edited in its main checkout.")
        end
      end

      if INLINE_MR_DESCRIPTION.match?(command)
        return blocked(command, "passes an MR description inline. Use mr-describe <iid> <file> to update one, or a shell script that reads the file to create one.")
      end

      if GIT_PUSH.match?(command)
        return blocked(command, "is a force push.") if FORCE_PUSH.match?(command)
        return blocked(command, "pushes a protected branch.") if PROTECTED_PUSH.match?(command)

        return
      end

      DANGEROUS_GIT.each do |pattern, label|
        if pattern.match?(command)
          return "BLOCKED: '#{command}' matches dangerous pattern '#{label}'. The user has prevented you from doing this.\n"
        end
      end

      nil
    end

    def self.shell_edit_message(command)
      if SED_IN_PLACE.match?(command) || PERL_IN_PLACE.match?(command)
        "BLOCKED: '#{command}' #{SHELL_EDIT_MESSAGE}\n"
      end

    end

    def self.change_writing_message(command, event, home)
      return unless writes_prose?(command, event, home)
      return if event["change_writing_applied"]

      transcript = event["transcript_path"]
      return if transcript && File.file?(transcript) && File.read(transcript).include?("# Change Writing")

      CHANGE_WRITING_MESSAGE
    end

    def self.writes_prose?(command, event, home)
      return true if MR_COMMAND.match?(command)
      return true if COMMIT_COMMAND.match?(command) && !/(?:--no-edit|--fixup)/.match?(command)

      command.scan(SHELL_SCRIPT).any? do |script|
        path = script_path(script, event.fetch("cwd"), home)
        File.file?(path) && MR_COMMAND.match?(File.read(path))
      end
    end

    def self.script_path(script, cwd, home)
      return script if script.start_with?("/")
      return script.sub("~/", "#{home}/") if script.start_with?("~/")

      "#{cwd}/#{script}"
    end

    def self.attribution_message(command)
      return unless COMMIT_COMMAND.match?(command) && COAUTHOR_ATTRIBUTION.match?(command)

      ATTRIBUTION_MESSAGE
    end

    def self.blocked(command, reason)
      "BLOCKED: '#{command}' #{reason} The user has prevented you from doing this.\n"
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
    private_class_method :call, :reminder, :reminder_output, :dangerous_git_message, :shell_edit_message,
      :change_writing_message, :writes_prose?, :script_path, :attribution_message, :blocked, :worktree_target
    private_constant :BLOCKED_MESSAGE, :CHANGE_WRITING_MESSAGE, :ATTRIBUTION_MESSAGE, :SHELL_EDIT_MESSAGE,
      :MR_REMINDER, :REVIEW_REMINDER, :WORKTREE_ADD, :BROAD_WORKTREE_ADD, :CHANGE_DIRECTORY,
      :INLINE_MR_DESCRIPTION, :GIT_PUSH, :FORCE_PUSH, :PROTECTED_PUSH, :DANGEROUS_GIT, :SED_IN_PLACE,
      :PERL_IN_PLACE, :MR_COMMAND, :COMMIT_COMMAND, :SHELL_SCRIPT, :COAUTHOR_ATTRIBUTION
  end
end
