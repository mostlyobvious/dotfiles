require "minitest/autorun"
require_relative "support/guard_runner"

class AgentGuardTest < Minitest::Test
  include GuardRunner

  BLOCKED_MESSAGE = "BLOCKED: create worktrees through the session host so every command starts in the worktree.\n"

  def test_direct_worktree_creation_uses_enter_worktree
    result = run_guard("git worktree add ../feature")

    assert_equal 2, result[:status]
    assert_equal "", result[:stdout]
    assert_equal BLOCKED_MESSAGE, result[:stderr]
  end

  def test_worktree_creation_with_an_explicit_repository_uses_enter_worktree
    result = run_guard("git -C ~/Code/backend/backend worktree add ../backend-feature")

    assert_equal 2, result[:status]
    assert_equal "", result[:stdout]
    assert_equal BLOCKED_MESSAGE, result[:stderr]
  end

  def test_other_commands_with_an_explicit_repository_continue
    result = run_guard("git -C ~/Code/backend/backend status --short")

    assert_equal 0, result[:status]
    assert_equal "", result[:stdout]
    assert_equal "", result[:stderr]
  end

  def test_entering_a_worktree_from_another_directory_uses_enter_worktree
    target = "#{HOME}/Code/worktrees/backend/feature"
    result = run_guard("cd ~/Code/worktrees/backend/feature && bundle exec rake")

    assert_equal 2, result[:status]
    assert_equal "", result[:stdout]
    assert_equal "BLOCKED: this session runs in /tmp/repository. Start or move the session to #{target} so every command starts there, then rerun without the cd.\n", result[:stderr]
  end

  def test_commands_inside_the_target_worktree_continue
    result = run_guard(
      "cd $HOME/Code/worktrees/backend/feature && bundle exec rake",
      cwd: "#{HOME}/Code/worktrees/backend/feature/app"
    )

    assert_equal 0, result[:status]
    assert_equal "", result[:stdout]
    assert_equal "", result[:stderr]
  end

end
