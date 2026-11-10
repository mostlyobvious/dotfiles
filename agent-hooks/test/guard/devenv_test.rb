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

    def test_bare_uv_is_blocked_in_a_python_worktree
      with_python_worktree do |root, home|
        assert_equal [2, PYTHON_DEVENV_MESSAGE],
                     call("uv run pytest", cwd: root, home: home)
      end
    end

    def test_bare_python_tool_is_blocked_in_a_python_worktree
      with_python_worktree do |root, home|
        assert_equal [2, PYTHON_DEVENV_MESSAGE],
                     call("pytest", cwd: root, home: home)
      end
    end

    def test_environment_prefix_does_not_hide_a_python_tool
      with_python_worktree do |root, home|
        assert_equal [2, PYTHON_DEVENV_MESSAGE],
                     call("env FOO=bar python -m pytest", cwd: root, home: home)
      end
    end

    def test_python_tool_path_is_blocked
      with_python_worktree do |root, home|
        assert_equal [2, PYTHON_DEVENV_MESSAGE],
                     call("/usr/bin/pytest", cwd: root, home: home)
      end
    end

    def test_python3_is_blocked
      with_python_worktree do |root, home|
        assert_equal [2, PYTHON_DEVENV_MESSAGE],
                     call("python3 script.py", cwd: root, home: home)
      end
    end

    def test_environment_assignment_is_allowed
      with_python_worktree do |root, home|
        assert_equal [0, ""], call("FOO=bar", cwd: root, home: home)
      end
    end

    def test_earlier_command_does_not_hide_a_python_tool
      with_python_worktree do |root, home|
        assert_equal [2, PYTHON_DEVENV_MESSAGE],
                     call("printf ready && ruff check", cwd: root, home: home)
      end
    end

    def test_wrapped_python_tool_is_allowed
      with_python_worktree do |root, home|
        assert_equal [0, ""],
                     call(
                       "devenv shell -- uv run pytest",
                       cwd: root,
                       home: home
                     )
      end
    end

    def test_uv_tool_environment_is_allowed
      with_python_worktree do |root, home|
        assert_equal [0, ""],
                     call("uv tool run ruff check", cwd: root, home: home)
      end
    end

    def test_uvx_is_allowed
      with_python_worktree do |root, home|
        assert_equal [0, ""], call("uvx ruff check", cwd: root, home: home)
      end
    end

    def test_global_python_is_allowed_outside_a_python_project
      with_worktree do |root, home|
        File.write("#{root}/devenv.nix", "{ }\n")

        assert_equal [0, ""], call("python script.py", cwd: root, home: home)
      end
    end

    def test_python_project_without_devenv_is_not_guarded
      with_worktree do |root, home|
        File.write("#{root}/pyproject.toml", "[project]\nname = 'example'\n")

        assert_equal [0, ""], call("python script.py", cwd: root, home: home)
      end
    end

    def test_nested_global_python_is_allowed_outside_a_python_project
      with_worktree do |root, home|
        nested = "#{root}/scripts/tools"
        FileUtils.mkdir_p(nested)
        File.write("#{root}/devenv.nix", "{ }\n")

        assert_equal [0, ""], call("python task.py", cwd: nested, home: home)
      end
    end

    def test_global_python_is_allowed_from_a_symlinked_worktree
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
        File.write("#{actual}/devenv.nix", "{ }\n")
        File.symlink(actual, root)

        assert_equal [0, ""], call("python task.py", cwd: root, home: home)
      end
    end

    def test_nested_python_project_is_guarded
      with_python_worktree do |root, home|
        nested = "#{root}/packages/app"
        FileUtils.mkdir_p(nested)
        FileUtils.mv(
          "#{root}/pyproject.toml",
          "#{root}/packages/pyproject.toml"
        )

        assert_equal [2, PYTHON_DEVENV_MESSAGE],
                     call("pyright", cwd: nested, home: home)
      end
    end

    def test_uv_lock_identifies_a_python_project
      with_worktree do |root, home|
        File.write("#{root}/devenv.nix", "{ }\n")
        File.write("#{root}/uv.lock", "version = 1\n")

        assert_equal [2, PYTHON_DEVENV_MESSAGE],
                     call("mutmut run", cwd: root, home: home)
      end
    end

    private

    def with_python_worktree
      with_worktree do |root, home|
        File.write("#{root}/devenv.nix", "{ }\n")
        File.write("#{root}/pyproject.toml", "[project]\nname = 'example'\n")
        yield root, home
      end
    end
  end
end
