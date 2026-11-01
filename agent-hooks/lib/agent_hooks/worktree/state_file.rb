require "fileutils"
require "json"

module AgentHooks
  module Worktree
    module StateFile
      def self.update(env)
        directory = File.join(state_home(env), "agent-worktree")
        FileUtils.mkdir_p(directory)
        lock = File.new("#{directory}/lock", File::CREAT, 0o600)
        begin
          lock.flock(File::LOCK_EX)
          path = "#{directory}/state.json"
          state = load(path)
          yield state
          File.write("#{path}.next", JSON.generate(state))
          File.rename("#{path}.next", path)
        ensure
          lock.close
        end
      end

      def self.state_home(env)
        env["XDG_STATE_HOME"] || File.join(env.fetch("HOME"), ".local", "state")
      end

      def self.load(path)
        return { "roots" => {} } unless File.file?(path)

        normalize(JSON.parse(File.read(path)))
      end

      def self.normalize(state)
        return state unless state.key?("sessions")

        seen = state.fetch("seen")
        roots =
          state
            .fetch("roots")
            .to_h do |root, sessions|
              owners =
                sessions.to_h { |session| [session, seen.fetch(session)] }
              [root, { "owners" => owners }]
            end
        { "roots" => roots }
      end

      private_class_method :state_home, :load, :normalize
    end
    private_constant :StateFile
  end
end
