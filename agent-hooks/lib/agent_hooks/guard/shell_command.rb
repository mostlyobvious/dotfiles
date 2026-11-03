require "json"
require "open3"

module AgentHooks
  module Guard
    module ShellCommand
      SHFMT = "shfmt"
      INSPECTED = %w[cd devenv gh git glab mr-describe perl sed].freeze
      STATIC = %w[Lit SglQuoted DblQuoted ParamExp].freeze
      MARKER = "$(...)"

      Program = Struct.new(:commands, :error, keyword_init: true)
      Invocation =
        Struct.new(:words, :dynamic, keyword_init: true) do
          ASSIGNMENT = /\A[A-Za-z_][A-Za-z0-9_]*=/

          def argv
            command_entries.map(&:first)
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

          def git_directory
            return unless git?

            options = arguments.take(arguments.length - git_parts.length)
            options.last
          end

          def dynamic?
            dynamic.any?
          end

          def dynamic_executable?
            command_entries.first&.last
          end

          def inspected?
            name = executable.to_s
            name.end_with?(".sh") || INSPECTED.include?(File.basename(name))
          end

          private

          def command_entries
            remaining = words.zip(dynamic)
            while (word = remaining.first&.first) &&
                    (word == "env" || ASSIGNMENT.match?(word))
              remaining.shift
            end
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
        output, error, status =
          Open3.capture3(SHFMT, "--to-json", stdin_data: source)
        unless status.success?
          return(
            Program.new(
              commands: [],
              error: "the shell parser reports #{error.chomp}"
            )
          )
        end

        program(JSON.parse(output))
      rescue SystemCallError => error
        Program.new(
          commands: [],
          error: "the shell parser is unavailable (#{error})"
        )
      end

      def self.program(tree)
        commands = []
        collect(tree, commands)
        Program.new(
          commands: commands,
          error: commands.filter_map { |command| reason(command) }.first
        )
      end

      def self.collect(node, commands)
        case node
        when Hash
          commands << invocation(node) if node["Type"] == "CallExpr"
          node.each_value { |child| collect(child, commands) }
        when Array
          node.each { |child| collect(child, commands) }
        end
      end

      def self.invocation(node)
        parts =
          Array(node["Assigns"]).map { |assign| assignment(assign) } +
            Array(node["Args"]).map { |word| word.fetch("Parts") }
        Invocation.new(
          words: parts.map { |part| text(part) },
          dynamic: parts.map { |part| dynamic?(part) }
        )
      end

      def self.assignment(assign)
        name = assign.fetch("Name").fetch("Value")
        value = assign["Value"]
        [{ "Type" => "Lit", "Value" => "#{name}=" }] +
          Array(value && value.fetch("Parts"))
      end

      def self.text(parts)
        parts
          .map do |part|
            case part.fetch("Type")
            when "Lit"
              part.fetch("Value").gsub(/\\(.)/, '\1')
            when "SglQuoted"
              part["Value"]
            when "DblQuoted"
              text(Array(part["Parts"]))
            when "ParamExp"
              "$#{part.fetch("Param").fetch("Value")}"
            else
              MARKER
            end
          end
          .join
      end

      def self.dynamic?(node)
        case node
        when Hash
          (node.key?("Type") && !STATIC.include?(node.fetch("Type"))) ||
            dynamic?(node.values)
        when Array
          node.any? { |child| dynamic?(child) }
        end
      end

      def self.reason(command)
        return unless command.dynamic?
        if command.dynamic_executable?
          return "the command name comes from a substitution"
        end
        return unless command.inspected?

        "#{File.basename(command.executable)} takes a value from a substitution"
      end

      private_class_method :collect,
                           :invocation,
                           :assignment,
                           :text,
                           :dynamic?,
                           :reason
      private_constant :SHFMT,
                       :INSPECTED,
                       :STATIC,
                       :MARKER,
                       :Program,
                       :Invocation
    end
    private_constant :ShellCommand
  end
end
