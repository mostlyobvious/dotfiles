require "open3"

module AgentHooks
  module Guard
    module GitRepository
      Repository = Struct.new(:root, :branch, keyword_init: true)

      def self.current(cwd)
        root = capture(cwd, %w[rev-parse --show-toplevel])
        branch = capture(cwd, %w[branch --show-current])
        Repository.new(root: root.chomp, branch: branch.chomp)
      end

      def self.capture(cwd, arguments)
        output, = Open3.capture3("git", "-C", cwd, *arguments)
        output
      end

      private_class_method :capture
      private_constant :Repository
    end
    private_constant :GitRepository
  end
end
