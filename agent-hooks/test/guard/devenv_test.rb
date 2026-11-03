require_relative "../support/guard_helpers"

module AgentHooks
  class DevenvPolicyTest < Minitest::Test
    include GuardHelpers
    cover "AgentHooks::Guard::Policies::Devenv*"
    cover "AgentHooks::Guard::GitRepository*"
    cover "AgentHooks::Guard::Policies.evaluate"

    def test_worktree_devenv_starts_detached
      with_worktree do |root, home|
        assert_equal [2, DEVENV_DETACH_MESSAGE],
                     call("devenv up", cwd: root, home: home)
      end
    end

    def test_worktree_devenv_starts_from_the_root
      with_worktree do |root, home|
        nested = "#{root}/app"
        FileUtils.mkdir_p(nested)

        assert_equal [2, DEVENV_ROOT_MESSAGE],
                     call("devenv up -d", cwd: nested, home: home)
      end
    end

    def test_detached_worktree_devenv_from_the_root_is_allowed
      with_worktree do |root, home|
        assert_equal [0, ""], call("devenv up -d", cwd: root, home: home)
      end
    end

    def test_symlinked_worktree_root_is_allowed
      Dir.mktmpdir do |home|
        actual = "#{home}/actual"
        root = "#{home}/Code/worktrees/project/task"
        FileUtils.mkdir_p(File.dirname(root))
        system(
          "git",
          "init",
          "--quiet",
          "--initial-branch=feature",
          actual,
          out: File::NULL,
          err: File::NULL
        ) or raise "git init failed"
        File.symlink(actual, root)

        assert_equal [0, ""], call("devenv up -d", cwd: root, home: home)
      end
    end

    def test_devenv_outside_a_worktree_is_allowed
      assert_equal [0, ""], call("devenv up")
    end

    def test_devenv_after_another_command_is_guarded
      with_worktree do |root, home|
        assert_equal [2, DEVENV_DETACH_MESSAGE],
                     call("printf ready && devenv up", cwd: root, home: home)
      end
    end

    def test_other_devenv_subcommand_in_a_worktree_is_allowed
      with_worktree do |root, home|
        assert_equal [0, ""], call("devenv shell", cwd: root, home: home)
      end
    end

    def test_other_devenv_subcommand_does_not_hide_later_startup
      with_worktree do |root, home|
        assert_equal [2, DEVENV_DETACH_MESSAGE],
                     call("devenv shell && devenv up", cwd: root, home: home)
      end
    end

    def test_detached_devenv_in_a_non_repository_worktree_path_is_blocked
      Dir.mktmpdir do |home|
        root = "#{home}/Code/worktrees/project/task"
        FileUtils.mkdir_p(root)

        assert_equal [2, DEVENV_ROOT_MESSAGE],
                     call("devenv up -d", cwd: root, home: home)
      end
    end

    def test_unrelated_up_command_in_a_worktree_is_allowed
      with_worktree do |root, home|
        assert_equal [0, ""], call("tool up", cwd: root, home: home)
      end
    end
  end
end
