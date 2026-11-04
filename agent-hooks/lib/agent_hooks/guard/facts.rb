require "fileutils"
require "json"

module AgentHooks
  module Guard
    module Facts
      DESCRIPTION = /desc.*\.md\z/i

      def self.update(home, session)
        return yield({}) unless session

        directory = "#{home}/.local/state/agent-guard"
        FileUtils.mkdir_p(directory)
        path = "#{directory}/#{session}.json"
        lock = File.new("#{directory}/lock", File::CREAT, 0o600)
        begin
          lock.flock(File::LOCK_EX)
          facts = File.file?(path) ? JSON.parse(File.read(path)) : {}
          result = yield facts
          File.write("#{path}.next", JSON.generate(facts))
          File.rename("#{path}.next", path)
          result
        ensure
          lock.close
        end
      end

      def self.forget(home, session)
        FileUtils.rm_f("#{home}/.local/state/agent-guard/#{session}.json")
      end

      def self.prompt(facts, text)
        facts["prompt"] = text
      end

      def self.observe(facts, event)
        input = event.fetch("tool_input")
        case event["tool_name"]
        when "Skill"
          if input["skill"] == "change-writing"
            facts["change_writing"] = true
            facts.delete("edits")
          end
        when "Edit", "Write"
          facts["edits"] = facts.fetch("edits", []) + [input.fetch("file_path")]
        end
      end

      def self.approve(facts, command)
        if facts["prompt"] == "go" && facts["pending"] == command
          facts.delete("pending")
          return true
        end

        facts["pending"] = command
        facts.delete("prompt")
        false
      end

      def self.change_writing?(facts)
        facts["change_writing"] == true
      end

      def self.description_edited?(facts, file)
        edits = facts.fetch("edits", [])
        if file
          edits.include?(file)
        else
          edits.any? { |path| DESCRIPTION.match?(File.basename(path)) }
        end
      end

      private_constant :DESCRIPTION
    end
    private_constant :Facts
  end
end
