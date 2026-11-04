require_relative "support/guard_helpers"

module AgentHooks
  class GuardTest < Minitest::Test
    include GuardHelpers
    cover "AgentHooks::Guard.run"
    cover "AgentHooks::Guard.reminder"
    cover "AgentHooks::Guard.reminder_output"
    cover "AgentHooks::Guard::Facts.update"
    cover "AgentHooks::Guard::Facts.forget"
    cover "AgentHooks::Guard::Facts.prompt"
    cover "AgentHooks::Guard::Facts.approve"

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

    def test_pre_tool_use_without_a_command_runs_tool_policies
      assert_equal [2, CHANGE_WRITING_MESSAGE], artifact(title: "Release notes")
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

    def test_prompt_is_recorded_without_output
      with_session do |home, session|
        assert_equal [0, "", nil], prompt(home, session, "go")
      end
    end

    def test_go_after_a_block_unlocks_the_retry
      with_session do |home, session|
        command = "git push origin main"
        call(command, home: home, session_id: session)
        prompt(home, session, "go")

        assert_equal [0, ""], call(command, home: home, session_id: session)
      end
    end

    def test_skill_result_is_recorded_without_output
      with_session do |home, session|
        assert_equal [0, "", nil], change_writing(home, session)
      end
    end

    def test_change_writing_skill_unlocks_commits
      with_session do |home, session|
        change_writing(home, session)

        with_commit_message("Document hook policy\n") do |path|
          assert_equal [0, ""],
                       call(
                         "git commit -F #{path}",
                         home: home,
                         session_id: session
                       )
        end
      end
    end

    def test_facts_live_in_the_state_directory_of_the_home
      with_session do |home, session|
        prompt(home, session, "go")
        directory = "#{home}/.local/state/agent-guard"

        assert File.file?("#{directory}/#{session}.json")
        assert_equal 0o600, File.stat("#{directory}/lock").mode & 0o777
      end
    end

    def test_a_hook_waits_for_another_hook_holding_the_session_lock
      with_session do |home, session|
        prompt(home, session, "go")
        lock = File.open("#{home}/.local/state/agent-guard/lock")
        lock.flock(File::LOCK_EX)
        waiting = Thread.new { prompt(home, session, "go") }

        assert_nil waiting.join(0.2)

        lock.flock(File::LOCK_UN)
        assert_equal [0, "", nil], waiting.value
      ensure
        lock&.close
      end
    end

    def test_session_end_forgets_the_session
      with_session do |home, session|
        command = "git push origin main"
        call(command, home: home, session_id: session)
        prompt(home, session, "go")

        assert_equal [0, "", nil], finish(home, session)
        refute File.exist?(facts_file(home, session))
        assert_equal needs_go(command, "pushes a protected branch."),
                     call(command, home: home, session_id: session)
      end
    end

    def test_session_end_without_a_session_is_harmless
      assert_equal [0, "", nil], finish("/Users/agent", nil)
    end
  end
end
