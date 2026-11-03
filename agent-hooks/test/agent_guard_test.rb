require "minitest/autorun"
require_relative "support/guard_runner"
require_relative "support/repositories"

class AgentGuardTest < Minitest::Test
  include GuardRunner
  include Repositories

  BLOCKED_MESSAGE =
    "BLOCKED: use the session host's worktree tool (Claude Code: EnterWorktree) instead of git worktree add so every command starts in the worktree. For another repository's worktree, run git -C <repository> worktree add ~/Code/worktrees/<repository name>/<name>.\n"

  def test_direct_worktree_creation_uses_enter_worktree
    result = run_guard("git worktree add ../feature")

    assert_equal 2, result[:status]
    assert_equal "", result[:stdout]
    assert_equal BLOCKED_MESSAGE, result[:stderr]
  end

  def test_worktree_creation_with_an_explicit_repository_uses_enter_worktree
    result =
      run_guard("git -C ~/Code/backend/backend worktree add ../backend-feature")

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

  def test_environment_assignment_continues
    result = run_guard("FOO=bar")

    assert_equal 0, result[:status]
    assert_equal "", result[:stdout]
    assert_equal "", result[:stderr]
  end

  def test_entering_a_worktree_from_another_directory_uses_enter_worktree
    with_repositories do |backend, home|
      target = "#{home}/Code/worktrees/backend/feature"
      result =
        run_guard(
          "cd ~/Code/worktrees/backend/feature && bundle exec rake",
          cwd: backend,
          home: home
        )

      assert_equal 2, result[:status]
      assert_equal "", result[:stdout]
      assert_equal "BLOCKED: this session runs in #{backend}. Use the session host's worktree tool (Claude Code: EnterWorktree) with path #{target}, then rerun the command without cd.\n",
                   result[:stderr]
    end
  end

  def test_entering_another_repository_worktree_continues
    with_repositories do |backend, home|
      result =
        run_guard(
          "cd ~/Code/worktrees/renovate/job && bundle exec rake",
          cwd: backend,
          home: home
        )

      assert_equal 0, result[:status]
      assert_equal "", result[:stderr]
    end
  end

  def test_other_repository_worktree_creation_continues
    with_repositories do |backend, home|
      result =
        run_guard(
          "git -C ~/Code/renovate worktree add -b job ~/Code/worktrees/renovate/job origin/main",
          cwd: backend,
          home: home
        )

      assert_equal 0, result[:status]
      assert_equal "", result[:stderr]
    end
  end

  def test_commands_inside_the_target_worktree_continue
    result =
      run_guard(
        "cd $HOME/Code/worktrees/backend/feature && bundle exec rake",
        cwd: "#{HOME}/Code/worktrees/backend/feature/app"
      )

    assert_equal 0, result[:status]
    assert_equal "", result[:stdout]
    assert_equal "", result[:stderr]
  end
end
