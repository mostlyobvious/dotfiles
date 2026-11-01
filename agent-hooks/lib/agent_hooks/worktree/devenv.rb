module AgentHooks
  module Worktree
    module Devenv
      START = /
        (?:\A | [&|;(]\s*)
        devenv
        (?:\s+ [^&|;\s]+)*
        \s+ up
        (?:\s | \z)
      /x
      NO_PROCESS_MANAGER = "No process manager is running"

      def self.started_root(event)
        case [event.fetch("tool_input").dig("command"), event["cwd"]]
        in [String => command, String => cwd] if START.match?(command)
          result = CommandRunner.run(["git", "-C", cwd, "rev-parse", "--show-toplevel"])
          result.output.chomp if result.success
        else
        end
      end

      def self.stop(root, err)
        return true unless File.directory?(root)

        result = CommandRunner.run(["devenv", "down"], chdir: root)
        return true if result.success || result.output.include?(NO_PROCESS_MANAGER)

        err.puts("Failed to stop devenv processes for #{root}: #{result.output}")
      end
      private_constant :START, :NO_PROCESS_MANAGER
    end
    private_constant :Devenv
  end
end
