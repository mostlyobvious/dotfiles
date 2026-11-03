require_relative "../support/guard_helpers"

module AgentHooks
  class UnsupportedShellPolicyTest < Minitest::Test
    include GuardHelpers
    cover "AgentHooks::Guard::Policies::UnsupportedShell*"
    cover "AgentHooks::Guard::ShellCommand*"
    cover "AgentHooks::Guard::Policies.evaluate"

    def test_environment_assignment_is_allowed
      assert_equal [0, ""], call("FOO=bar")
    end

    def test_non_git_worktree_command_is_allowed
      assert_equal [0, ""], call("worktree add feature")
    end

    def test_each_command_in_a_chain_is_guarded
      command = "git push origin feature && git reset --hard"

      expected =
        "BLOCKED: '#{command}' matches dangerous pattern 'git reset --hard'. Ask the user for exact 'go', then retry unchanged.\n"

      assert_equal [2, expected], call(command)
    end

    def test_quoted_dangerous_command_is_plain_text
      assert_equal [0, ""], call("printf 'git reset --hard'")
    end

    {
      "quoted substitution" => 'printf "$(date)"',
      "substitution argument" => "readlink -f $(which pi)",
      "backtick argument" => "ls `pwd`",
      "assigned substitution" => "latest=$(ls -t /tmp)",
      "piped substitution" => "jq . $(ls -t /tmp | head -1)",
      "two substitutions" => "diff $(ls /a) $(ls /b)",
      "single-quoted backtick" => "rg 'a`b|$(c' lib",
      "escaped substitution" => 'printf \$\(date\)',
      "nested substitution" => "printf $(dirname $(pwd))",
      "quoted inner command" => "printf $(git log --format='%h')",
      "quotes inside a substitution" => "stree write $(find lib -name '*.rb')",
      "comment after the command" => "git status # $(reboot)",
      "loop that only reads" => "for f in a b; do printf $f; done",
      "variable executable" => "$EDITOR file"
    }.each do |name, command|
      define_method("test_#{name.tr(" -", "__")}_is_allowed") do
        assert_equal [0, ""], call(command)
      end
    end

    {
      "git argument" => [
        "git push origin $(git branch --show-current)",
        "git takes a value from a substitution"
      ],
      "quoted git argument" => [
        'git push origin "$(git branch --show-current)"',
        "git takes a value from a substitution"
      ],
      "process substitution into git" => [
        "git commit -F <(printf Subject)",
        "git takes a value from a substitution"
      ],
      "dynamic executable" => [
        "$(which git) status",
        "the command name comes from a substitution"
      ],
      "git by path" => [
        "/usr/bin/git push origin $(pwd)",
        "git takes a value from a substitution"
      ],
      "script argument" => [
        "./publish.sh $(pwd)",
        "publish.sh takes a value from a substitution"
      ],
      "environment-prefixed git" => [
        "env REF=$(pwd) git status",
        "git takes a value from a substitution"
      ],
      "unterminated substitution" => [
        "printf $(date",
        "the shell parser reports 1:8: reached EOF without matching `$(` with `)`"
      ],
      "unclosed quote" => [
        "printf 'unfinished",
        "the shell parser reports 1:8: reached EOF without closing quote `'`"
      ]
    }.each do |name, (command, reason)|
      define_method("test_#{name.tr(" -", "__")}_cannot_be_inspected") do
        assert_equal [2, cannot_inspect(reason)], call(command)
      end
    end

    def test_first_uninspectable_command_names_the_reason
      assert_equal [
                     2,
                     cannot_inspect(
                       "the command name comes from a substitution"
                     )
                   ],
                   call("$(which git) status && git push $(x)")
    end

    def test_a_later_uninspectable_command_is_still_found
      assert_equal [2, cannot_inspect("git takes a value from a substitution")],
                   call("printf ok && git push $(x)")
    end

    def test_missing_shell_parser_blocks_every_command
      path = ENV.fetch("PATH")
      ENV["PATH"] = ""

      assert_equal [
                     2,
                     cannot_inspect(
                       "the shell parser is unavailable (No such file or directory - shfmt)"
                     )
                   ],
                   call("printf ready")
    ensure
      ENV["PATH"] = path
    end

    def test_substituted_force_push_is_guarded
      command = "printf $(git push --force origin feature)"

      assert_equal policy_blocked(
                     command,
                     "is a force push. Use --force-with-lease after an amend or rebase on a feature branch."
                   ),
                   call(command)
    end

    def test_loop_body_is_inspected
      assert_equal blocked,
                   call("for r in a b; do git worktree add ../$r; done")
    end

    def test_heredoc_commit_message_still_needs_a_file
      assert_equal [2, COMMIT_FILE_MESSAGE],
                   call(
                     "git commit -F - <<'EOF'\nSubject\nEOF\n",
                     change_writing_applied: true
                   )
    end
  end
end
