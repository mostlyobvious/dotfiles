require_relative "guard/shell_command"
require_relative "guard/git_repository"
require_relative "guard/approval"
require_relative "guard/policies"

module AgentHooks
  module Guard
    MR_REMINDER =
      "If the pushed branch has an open MR, compare its description with the new diff and propose an update when they disagree (merge-request skill, step 8)."
    REVIEW_REMINDER =
      "Run the change-writing Review Pass on mr-description.md before presenting it for approval (merge-request skill, step 6)."

    def self.run(event, home)
      if event.fetch("hook_event_name") == "PostToolUse"
        return 0, "", reminder(event)
      end

      command = event.fetch("tool_input")["command"] || ""
      context =
        Context.new(
          event: event,
          home: home,
          command: command,
          cwd: event.fetch("cwd"),
          program: ShellCommand.parse(command)
        )
      decision = Policies.evaluate(context)
      [decision.status, decision.message, nil]
    end

    def self.reminder(event)
      input = event.fetch("tool_input")
      command = input["command"]
      if command &&
           ShellCommand
             .parse(command)
             .commands
             .any? { |invocation| invocation.git_subcommand == "push" }
        return reminder_output(MR_REMINDER)
      end

      path = input["file_path"] || input["path"]
      if path && File.basename(path) == "mr-description.md"
        reminder_output(REVIEW_REMINDER)
      end
    end

    def self.reminder_output(message)
      {
        "hookSpecificOutput" => {
          "hookEventName" => "PostToolUse",
          "additionalContext" => message
        }
      }
    end

    private_class_method :reminder, :reminder_output
    private_constant :MR_REMINDER, :REVIEW_REMINDER
  end
end
