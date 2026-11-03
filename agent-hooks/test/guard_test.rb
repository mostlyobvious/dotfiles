require_relative "support/guard_helpers"

module AgentHooks
  class GuardTest < Minitest::Test
    include GuardHelpers
    cover "AgentHooks::Guard"

    def test_push_reminder_is_returned_after_tool_use
      output =
        Guard.run(
          {
            "hook_event_name" => "PostToolUse",
            "tool_input" => {
              "command" => "git push origin feature"
            }
          },
          "/Users/agent"
        )

      assert_equal [0, "", reminder(MR_REMINDER)], output
    end

    def test_push_in_a_command_chain_returns_the_merge_request_reminder
      output =
        Guard.run(
          {
            "hook_event_name" => "PostToolUse",
            "tool_input" => {
              "command" => "git push origin feature && git status"
            }
          },
          "/Users/agent"
        )

      assert_equal [0, "", reminder(MR_REMINDER)], output
    end

    def test_unparseable_push_returns_no_reminder
      output =
        Guard.run(
          {
            "hook_event_name" => "PostToolUse",
            "tool_input" => {
              "command" => "git push origin feature 'unfinished"
            }
          },
          "/Users/agent"
        )

      assert_equal [0, "", nil], output
    end

    def test_missing_shell_parser_returns_no_reminder
      path = ENV.fetch("PATH")
      ENV["PATH"] = ""
      output =
        Guard.run(
          {
            "hook_event_name" => "PostToolUse",
            "tool_input" => {
              "command" => "git push origin feature"
            }
          },
          "/Users/agent"
        )

      assert_equal [0, "", nil], output
    ensure
      ENV["PATH"] = path
    end

    def test_review_reminder_is_returned_for_description_write
      output =
        Guard.run(
          {
            "hook_event_name" => "PostToolUse",
            "tool_input" => {
              "file_path" => "/tmp/mr-description.md"
            }
          },
          "/Users/agent"
        )

      assert_equal [0, "", reminder(REVIEW_REMINDER)], output
    end

    def test_other_post_tool_use_has_no_reminder
      output =
        Guard.run(
          {
            "hook_event_name" => "PostToolUse",
            "tool_input" => {
              "command" => "git status"
            }
          },
          "/Users/agent"
        )

      assert_equal [0, "", nil], output
    end

    def test_pre_tool_use_runs_guard_policy
      output =
        Guard.run(
          {
            "hook_event_name" => "PreToolUse",
            "tool_input" => {
              "command" => "git commit -F /tmp/message"
            },
            "cwd" => "/tmp"
          },
          "/Users/agent"
        )

      assert_equal [2, CHANGE_WRITING_MESSAGE, nil], output
    end

    def test_pre_tool_use_passes_home_to_worktree_policy
      with_repositories do |backend, home|
        output =
          Guard.run(
            {
              "hook_event_name" => "PreToolUse",
              "tool_input" => {
                "command" => "cd ~/Code/worktrees/backend/feature"
              },
              "cwd" => backend
            },
            home
          )

        assert_equal [
                       *enter_worktree(
                         backend,
                         "#{home}/Code/worktrees/backend/feature"
                       ),
                       nil
                     ],
                     output
      end
    end

    def test_post_tool_use_file_without_command_has_no_push_reminder
      output =
        Guard.run(
          {
            "hook_event_name" => "PostToolUse",
            "tool_input" => {
              "file_path" => "/tmp/file.rb"
            }
          },
          "/Users/agent"
        )

      assert_equal [0, "", nil], output
    end

    def test_path_field_also_returns_review_reminder
      output =
        Guard.run(
          {
            "hook_event_name" => "PostToolUse",
            "tool_input" => {
              "path" => "mr-description.md"
            }
          },
          "/Users/agent"
        )

      assert_equal [0, "", reminder(REVIEW_REMINDER)], output
    end
  end
end
