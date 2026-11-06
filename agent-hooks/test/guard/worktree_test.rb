require_relative "../support/guard_helpers"

module AgentHooks
  class WorktreePolicyTest < Minitest::Test
    include GuardHelpers
    cover "AgentHooks::Guard::Policies::Worktree*"
    cover "AgentHooks::Guard::GitRepository*"
    cover "AgentHooks::Guard::Policies.evaluate"

    def test_direct_worktree_creation_is_blocked
      assert_equal blocked, call("git worktree add ../feature")
    end

    def test_explicit_repository_worktree_creation_is_blocked
      assert_equal blocked,
                   call("git -C ~/Code/backend/backend worktree add ../feature")
    end

    def test_worktree_creation_after_another_command_is_blocked
      assert_equal blocked, call("printf ready && git worktree add ../feature")
    end

    def test_worktree_list_is_allowed
      assert_equal [0, ""], call("git worktree list")
    end

    def test_other_command_with_add_argument_is_allowed
      assert_equal [0, ""], call("git branch add")
    end

    def test_other_repository_worktree_creation_is_allowed
      with_repositories do |backend, home|
        assert_equal [0, ""],
                     call(
                       "git -C ~/Code/renovate worktree add -b job ~/Code/worktrees/renovate/job origin/main",
                       cwd: backend,
                       home: home
                     )
        assert_equal [0, ""],
                     call(
                       "git -C $HOME/Code/renovate worktree add $HOME/Code/worktrees/renovate/job",
                       cwd: backend,
                       home: home
                     )
      end
    end

    def test_relative_worktree_paths_follow_the_named_repository
      with_repositories do |backend, home|
        app = "#{backend}/app"
        FileUtils.mkdir_p(app)

        assert_equal [0, ""],
                     call(
                       "git -C ../../renovate worktree add ../worktrees/renovate/job",
                       cwd: app,
                       home: home
                     )
      end
    end

    def test_other_repository_worktree_outside_its_worktree_directory_is_blocked
      with_repositories do |backend, home|
        assert_equal blocked,
                     call(
                       "git -C ~/Code/renovate worktree add ~/Code/worktrees/backend/job",
                       cwd: backend,
                       home: home
                     )
        assert_equal blocked,
                     call(
                       "git -C ~/Code/renovate worktree add ~/Code/worktrees/renovate/job/app",
                       cwd: backend,
                       home: home
                     )
        assert_equal blocked,
                     call(
                       "git -C ~/Code/renovate worktree add ~/Code/worktrees/renovate/",
                       cwd: backend,
                       home: home
                     )
        assert_equal blocked,
                     call(
                       "git -C ~/Code/renovate worktree add /tmp/Code/worktrees/renovate/job",
                       cwd: backend,
                       home: home
                     )
      end
    end

    def test_session_repository_worktree_creation_is_blocked
      with_repositories do |backend, home|
        assert_equal blocked,
                     call(
                       "git -C ~/Code/backend worktree add ~/Code/worktrees/backend/job",
                       cwd: backend,
                       home: home
                     )
      end
    end

    def test_worktree_creation_for_a_missing_repository_is_blocked
      with_repositories do |backend, home|
        assert_equal blocked,
                     call(
                       "git -C ~/Code/missing worktree add ~/Code/worktrees/missing/job",
                       cwd: backend,
                       home: home
                     )
      end
    end

    def test_entering_a_missing_worktree_asks_the_host_to_create_it
      with_repositories do |backend, home|
        assert_equal create_worktree(backend, "feature"),
                     call(
                       "cd ~/Code/worktrees/backend/feature && bundle exec rake",
                       cwd: backend,
                       home: home
                     )
      end
    end

    def test_entering_an_existing_worktree_asks_the_host_to_reuse_its_name
      with_repositories do |backend, home|
        target = "#{home}/Code/worktrees/backend/feature"
        FileUtils.mkdir_p(target)

        assert_equal create_worktree(backend, "feature"),
                     call(
                       "cd ~/Code/worktrees/backend/feature && bundle exec rake",
                       cwd: backend,
                       home: home
                     )
      end
    end

    def test_entering_another_repository_worktree_is_allowed
      with_repositories do |backend, home|
        assert_equal [0, ""],
                     call(
                       "cd ~/Code/worktrees/renovate/job && bundle exec rake",
                       cwd: backend,
                       home: home
                     )
      end
    end

    def test_entering_a_worktree_outside_a_repository_is_allowed
      assert_equal [0, ""], call("cd ~/Code/worktrees/backend/feature")
    end

    def test_entering_a_worktree_later_in_a_command_chain_is_blocked
      with_repositories do |backend, home|
        assert_equal create_worktree(backend, "feature"),
                     call(
                       "printf ready && cd ~/Code/worktrees/backend/feature",
                       cwd: backend,
                       home: home
                     )
      end
    end

    def test_current_worktree_does_not_hide_a_later_worktree_transition
      with_backend_worktree do |feature, home|
        assert_equal create_worktree(feature, "other"),
                     call(
                       "cd ~/Code/worktrees/backend/feature && cd ~/Code/worktrees/backend/other",
                       cwd: feature,
                       home: home
                     )
      end
    end

    def test_entering_the_current_worktree_is_allowed
      with_backend_worktree do |feature, home|
        app = "#{feature}/app"
        FileUtils.mkdir_p(app)

        assert_equal [0, ""],
                     call(
                       "cd $HOME/Code/worktrees/backend/feature && bundle exec rake",
                       cwd: app,
                       home: home
                     )
      end
    end

    def test_entering_the_worktree_root_is_allowed
      with_backend_worktree do |feature, home|
        assert_equal [0, ""],
                     call(
                       "cd ~/Code/worktrees/backend/feature",
                       cwd: feature,
                       home: home
                     )
      end
    end

    def test_entering_a_regular_directory_is_allowed
      assert_equal [0, ""],
                   call("cd ~/Code/backend/backend && bundle exec rake")
    end

    def test_cd_without_a_path_is_allowed
      assert_equal [0, ""], call("cd")
    end

    def test_cd_without_a_path_does_not_hide_a_later_worktree_transition
      with_repositories do |backend, home|
        assert_equal create_worktree(backend, "feature"),
                     call(
                       "cd && cd ~/Code/worktrees/backend/feature",
                       cwd: backend,
                       home: home
                     )
      end
    end

    def test_regular_cd_does_not_hide_a_later_worktree_transition
      with_repositories do |backend, home|
        assert_equal create_worktree(backend, "feature"),
                     call(
                       "cd /tmp && cd ~/Code/worktrees/backend/feature",
                       cwd: backend,
                       home: home
                     )
      end
    end

    def test_other_repository_cd_does_not_hide_a_later_worktree_transition
      with_repositories do |backend, home|
        assert_equal create_worktree(backend, "feature"),
                     call(
                       "cd ~/Code/worktrees/renovate/job && cd ~/Code/worktrees/backend/feature",
                       cwd: backend,
                       home: home
                     )
      end
    end

    def test_worktree_repository_cd_does_not_hide_a_later_transition
      with_repositories do |backend, home|
        assert_equal create_worktree(backend, "feature"),
                     call(
                       "cd ~/Code/worktrees/backend && cd ~/Code/worktrees/backend/feature",
                       cwd: backend,
                       home: home
                     )
      end
    end

    def test_non_cd_command_with_a_worktree_path_is_allowed
      with_repositories do |backend, home|
        assert_equal [0, ""],
                     call(
                       "printf ~/Code/worktrees/backend/feature",
                       cwd: backend,
                       home: home
                     )
      end
    end

    def test_a_regular_command_with_a_relative_cwd_is_allowed
      assert_equal [0, ""], call("printf ready", cwd: "repository")
    end

    def test_entering_a_repository_worktree_directory_is_allowed
      assert_equal [0, ""], call("cd ~/Code/worktrees/backend")
    end

    def test_a_similar_worktree_prefix_is_allowed
      assert_equal [0, ""],
                   call("cd /Users/agent/Code/worktrees-other/backend/feature")
    end

    def test_home_variable_worktree_path_is_blocked
      with_repositories do |backend, home|
        assert_equal create_worktree(backend, "feature"),
                     call(
                       "cd $HOME/Code/worktrees/backend/feature",
                       cwd: backend,
                       home: home
                     )
      end
    end

    def test_worktree_subdirectory_names_the_worktree_root
      with_repositories do |backend, home|
        assert_equal create_worktree(backend, "feature"),
                     call(
                       "cd ~/Code/worktrees/backend/feature/app",
                       cwd: backend,
                       home: home
                     )
      end
    end

    def test_session_repository_worktree_from_a_subdirectory_is_blocked
      with_repositories do |backend, home|
        app = "#{backend}/app"
        FileUtils.mkdir_p(app)

        assert_equal blocked,
                     call(
                       "git -C ~/Code/backend worktree add ~/Code/worktrees/backend/job",
                       cwd: app,
                       home: home
                     )
      end
    end
  end
end
