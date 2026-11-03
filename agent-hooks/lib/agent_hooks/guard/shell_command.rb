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
      TOKEN = /('[^']*')|("(?:\\.|[^"\\])*"|\\.|[^'"\\]+|.)/m
      SUBSTITUTION = /\$\(([^()`]*)\)|`([^`]*)`/
      PLACEHOLDER = "__agent_guard_substitution__"
      INSPECTED = %w[cd devenv gh git glab mr-describe perl sed].freeze

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
        supported = true
        substitutions = []
        static =
          source
            .scan(TOKEN)
            .map do |quoted, token|
              next quoted if quoted

              replaced =
                token.gsub(SUBSTITUTION) do
                  match = Regexp.last_match
                  substitutions << (match[1] || match[2])
                  PLACEHOLDER
                end
              supported = false if DYNAMIC_COMMAND.match?(replaced)
              replaced
            end
            .join
        commands =
          static
            .scan(SEGMENT)
            .map do |segment|
              words = Shellwords.shellsplit(segment)
              Invocation.new(words: words)
            rescue ArgumentError
              supported = false
            end
        if commands.any? { |command|
             command && substituted_inspection?(command)
           }
          supported = false
        end
        commands += substitutions.flat_map { |inner| parse(inner).commands }
        Program.new(commands: commands, supported: supported)
      end

      def self.substituted_inspection?(command)
        unless command.words.any? { |word| word.include?(PLACEHOLDER) }
          return false
        end

        executable = command.executable.to_s
        executable.include?(PLACEHOLDER) || executable.end_with?(".sh") ||
          INSPECTED.include?(File.basename(executable))
      end

      private_class_method :substituted_inspection?
      private_constant :SEGMENT,
                       :DYNAMIC_COMMAND,
                       :TOKEN,
                       :SUBSTITUTION,
                       :PLACEHOLDER,
                       :INSPECTED,
                       :Program,
                       :Invocation
    end
    private_constant :ShellCommand
  end
end
