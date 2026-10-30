require "minitest/autorun"
require "mutant/minitest/coverage"
require_relative "../lib/agent_hooks/guard"

module AgentHooks
  class GuardTest < Minitest::Test
    cover "AgentHooks::Guard*"

    def test_direct_worktree_creation_is_blocked
      assert_equal blocked, call("git worktree add ../feature")
    end

    def test_explicit_repository_worktree_creation_is_blocked
      assert_equal blocked, call("git -C ~/Code/backend/backend worktree add ../feature")
    end

    def test_worktree_creation_after_another_command_is_blocked
      assert_equal blocked, call("printf ready && git worktree add ../feature")
    end

    def test_unrelated_git_command_is_allowed
      assert_equal [0, ""], call("git -C ~/Code/backend/backend status --short")
    end

    def test_sed_short_in_place_option_is_blocked
      assert_equal shell_edit_blocked("sed -i '' 's/old/new/' file"), call("sed -i '' 's/old/new/' file")
    end

    def test_sed_long_in_place_option_is_blocked
      command = "sed --in-place=.bak 's/old/new/' file"

      assert_equal shell_edit_blocked(command), call(command)
    end

    def test_sed_in_place_after_another_command_is_blocked
      command = "printf ready && sed -i.bak 's/old/new/' file"

      assert_equal shell_edit_blocked(command), call(command)
    end

    def test_perl_in_place_option_is_blocked
      command = "perl -pi -e 's/old/new/' file"

      assert_equal shell_edit_blocked(command), call(command)
    end

    def test_perl_combined_in_place_option_is_blocked
      command = "perl -0777pi -e 's/old/new/' file"

      assert_equal shell_edit_blocked(command), call(command)
    end

    def test_sed_that_writes_to_stdout_is_allowed
      assert_equal [0, ""], call("sed 's/old/new/' file")
    end

    def test_similar_command_name_is_allowed
      assert_equal [0, ""], call("sediment -i file")
    end

    def test_perl_without_in_place_option_is_allowed
      assert_equal [0, ""], call("perl -pe 's/old/new/' file")
    end

    def test_entering_a_worktree_from_another_directory_is_blocked
      target = "/Users/agent/Code/worktrees/backend/feature"

      assert_equal [2, "BLOCKED: this session runs in /tmp/repository. Call EnterWorktree with path #{target} so every command starts there, then rerun without the cd.\n"], call("cd ~/Code/worktrees/backend/feature && bundle exec rake")
    end

    def test_entering_the_current_worktree_is_allowed
      assert_equal [0, ""], call(
        "cd $HOME/Code/worktrees/backend/feature && bundle exec rake",
        cwd: "/Users/agent/Code/worktrees/backend/feature/app"
      )
    end

    def test_entering_the_worktree_root_is_allowed
      assert_equal [0, ""], call(
        "cd ~/Code/worktrees/backend/feature",
        cwd: "/Users/agent/Code/worktrees/backend/feature"
      )
    end

    def test_entering_a_regular_directory_is_allowed
      assert_equal [0, ""], call("cd ~/Code/backend/backend && bundle exec rake")
    end

    def test_a_regular_command_with_a_relative_cwd_is_allowed
      assert_equal [0, ""], call("printf ready", cwd: "repository")
    end

    def test_entering_a_repository_worktree_directory_is_allowed
      assert_equal [0, ""], call("cd ~/Code/worktrees/backend")
    end

    def test_a_similar_worktree_prefix_is_allowed
      assert_equal [0, ""], call("cd /Users/agent/Code/worktrees-other/backend/feature")
    end

    def test_home_variable_worktree_path_is_blocked
      target = "/Users/agent/Code/worktrees/backend/feature"

      assert_equal [2, "BLOCKED: this session runs in /tmp/repository. Call EnterWorktree with path #{target} so every command starts there, then rerun without the cd.\n"], call("cd $HOME/Code/worktrees/backend/feature")
    end

    def test_worktree_subdirectory_names_the_worktree_root
      target = "/Users/agent/Code/worktrees/backend/feature"

      assert_equal [2, "BLOCKED: this session runs in /tmp/repository. Call EnterWorktree with path #{target} so every command starts there, then rerun without the cd.\n"], call("cd ~/Code/worktrees/backend/feature/app")
    end

    private

    def blocked
      [2, Guard::BLOCKED_MESSAGE]
    end

    def shell_edit_blocked(command)
      [2, "BLOCKED: '#{command}' edits files through an in-place shell command. Use Edit for existing files or Write for new files and complete rewrites.\n"]
    end

    def call(command, cwd: "/tmp/repository")
      Guard.call(
        {"tool_input" => {"command" => command}, "cwd" => cwd},
        "/Users/agent"
      )
    end
  end
end
