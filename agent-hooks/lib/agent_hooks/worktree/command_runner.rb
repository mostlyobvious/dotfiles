module AgentHooks
  module Worktree
    module CommandRunner
      Result = Struct.new(:output, :success, keyword_init: true)

      def self.run(command, chdir: nil)
        options = { err: %i[child out] }
        options[:chdir] = chdir if chdir
        output = IO.popen(command, **options, &:read)
        Result.new(output: output, success: $?.success?)
      end
      private_constant :Result
    end
    private_constant :CommandRunner
  end
end
