require "shellwords"

module AgentHooks
  module Guard
    module ShellCommand
      SEGMENT =
        /
        (?:
          '(?:[^']*)'
          | "(?:\\.|[^"])*"
          | \\.
          | [^;&|()\n]
        )+
      /x
      DYNAMIC_COMMAND = /`|\$\(/

      Program = Struct.new(:commands, :supported, keyword_init: true)
      Invocation =
        Struct.new(:words, keyword_init: true) do
          ASSIGNMENT = /\A[A-Za-z_][A-Za-z0-9_]*=/

          def argv
            command_words
          end

          def executable
            argv.first
          end

          def arguments
            argv.drop(1)
          end

          def git?
            executable == "git"
          end

          def git_subcommand
            return unless git?

            git_parts.first
          end

          def git_arguments
            return [] unless git?

            git_parts.drop(1)
          end

          private

          def command_words
            remaining = words.dup
            remaining.shift if remaining.first == "env"
            remaining.shift while ASSIGNMENT.match?(remaining.first)
            remaining
          end

          def git_parts
            remaining = arguments.dup
            while remaining.first == "-C" && remaining.length > 1
              remaining.shift(2)
            end
            remaining
          end
        end

      def self.parse(source)
        supported = !DYNAMIC_COMMAND.match?(source)
        commands =
          source
            .scan(SEGMENT)
            .map do |segment|
              words = Shellwords.shellsplit(segment)
              Invocation.new(words: words)
            rescue ArgumentError
              supported = false
            end
        Program.new(commands: commands, supported: supported)
      end

      private_constant :SEGMENT, :DYNAMIC_COMMAND, :Program, :Invocation
    end
    private_constant :ShellCommand
  end
end
