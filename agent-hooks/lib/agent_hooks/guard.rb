require_relative "guard/facts"
require_relative "guard/shell_command"
require_relative "guard/git_repository"
require_relative "guard/policies"

module AgentHooks
  module Guard
    MR_REMINDER =
      "If the pushed branch has an open MR, compare its description with the new diff and propose an update when they disagree (merge-request skill, step 8)."
    REVIEW_REMINDER =
      "Run the change-writing Review Pass on mr-description.md before presenting it for approval (merge-request skill, step 6)."

    def self.run(event, home)
      session = event["session_id"]
      case event.fetch("hook_event_name")
      when "SessionEnd"
        Facts.forget(home, session)
        [0, "", nil]
      when "UserPromptSubmit"
        Facts.update(home, session) do |facts|
          Facts.prompt(facts, event.fetch("prompt"))
        end
        [0, "", nil]
      when "PostToolUse"
        Facts.update(home, session) { |facts| Facts.observe(facts, event) }
        [0, "", reminder(event)]
      else
        command = event.fetch("tool_input")["command"]
        context =
          Context.new(
            event: event,
            home: home,
            command: command,
            cwd: event.fetch("cwd"),
            program: ShellCommand.parse(command)
          )
        decision =
          Facts.update(home, session) do |facts|
            context.facts = facts
            Policies.evaluate(context)
          end
        [decision.status, decision.message, nil]
      end
    end

    def self.reminder(event)
      input = event.fetch("tool_input")
      if ShellCommand
           .parse(input["command"])
           .commands
           .any? { |invocation| invocation.git_subcommand == "push" }
        return reminder_output(MR_REMINDER)
      end

      path = input["file_path"]
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
