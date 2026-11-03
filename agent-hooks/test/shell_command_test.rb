require "minitest/autorun"
require "mutant/minitest/coverage"
require_relative "../lib/agent_hooks/guard"

module AgentHooks
  class ShellCommandTest < Minitest::Test
    cover "AgentHooks::Guard::ShellCommand*"

    ShellCommand = Guard.const_get(:ShellCommand)

    def test_assignments_and_env_prefix_stay_in_words_but_leave_argv
      command = parse("FOO=1 env BAR=2 git -C /r push").commands.first

      assert_equal %w[FOO=1 env BAR=2 git -C /r push], command.words
      assert_equal %w[git -C /r push], command.argv
      assert_equal "push", command.git_subcommand
      assert_equal "/r", command.git_directory
    end

    def test_quoting_is_resolved_and_escapes_are_dropped
      command = parse(%q{printf 'a b' "c $d" \$\(e\) $'n\n'}).commands.first

      assert_equal ["printf", "a b", "c $d", "$(e)", "n\\n"], command.words
      refute command.dynamic?
    end

    def test_empty_strings_stay_as_empty_words
      assert_equal ["sed", "-i", "", "x", ""],
                   parse(%q{sed -i '' x ""}).commands.first.words
    end

    def test_parameter_expansion_renders_as_the_bare_variable
      assert_equal %w[cd $HOME/x],
                   parse("cd ${HOME:-/tmp}/x").commands.first.words
    end

    def test_substitutions_render_as_a_marker_and_their_commands_are_listed
      program = parse("printf \"$(date) x\" <(sort a) $((1 + 2))")

      assert_equal [
                     ["printf", "$(...) x", "$(...)", "$(...)"],
                     ["date"],
                     %w[sort a]
                   ],
                   program.commands.map(&:words)
      assert program.commands.first.dynamic?
      refute program.commands.first.dynamic_executable?
      assert_nil program.error
    end

    def test_array_assignment_renders_its_name
      command = parse("arr=(1 $(ls))").commands.first

      assert_equal ["arr="], command.words
      refute command.dynamic?
    end

    def test_a_part_the_guard_does_not_read_counts_as_a_substitution
      tree = {
        "Type" => "CallExpr",
        "Args" => [
          { "Parts" => [{ "Type" => "Lit", "Value" => "git" }] },
          { "Parts" => [{ "Type" => "ExtGlob", "Op" => "+(" }] }
        ]
      }
      program = ShellCommand.program(tree)

      assert_equal %w[git $(...)], program.commands.first.words
      assert_equal "git takes a value from a substitution", program.error
    end

    def test_empty_source_has_no_commands
      program = parse("")

      assert_equal [], program.commands
      assert_nil program.error
    end

    def test_commands_inside_functions_and_conditionals_are_listed
      program = parse("f() { git status; }; if true; then sed -n 1p x; fi")

      assert_equal [%w[git status], %w[true], %w[sed -n 1p x]],
                   program.commands.map(&:words)
    end

    def test_parse_error_yields_no_commands
      program = parse("printf 'x")

      assert_equal [], program.commands
      assert_equal "the shell parser reports 1:8: reached EOF without closing quote `'`",
                   program.error
    end

    def test_missing_parser_yields_no_commands
      path = ENV.fetch("PATH")
      ENV["PATH"] = ""
      program = parse("printf x")

      assert_equal [], program.commands
      assert_equal "the shell parser is unavailable (No such file or directory - shfmt)",
                   program.error
    ensure
      ENV["PATH"] = path
    end

    private

    def parse(source)
      ShellCommand.parse(source)
    end
  end
end
