require_relative "../support/guard_helpers"

module AgentHooks
  class GitPolicyTest < Minitest::Test
    include GuardHelpers
    cover "AgentHooks::Guard::Policies::Git*"
    cover "AgentHooks::Guard::Policies.evaluate"
    cover "AgentHooks::Guard::Policies.blocked"
    cover "AgentHooks::Guard::Policies.unless_go"
    cover "AgentHooks::Guard::GitRepository*"
    cover "AgentHooks::Guard::Facts.approve"

    def test_unrelated_git_command_is_allowed
      assert_equal [0, ""], call("git -C ~/Code/backend/backend status --short")
    end

    def test_switching_branches_inside_a_linked_worktree_is_blocked
      with_backend_worktree do |feature, home|
        command = "git switch -q --detach origin/other"
        reason =
          "uses git switch or checkout inside a linked worktree. Use EnterWorktree for another branch or git restore for files."

        assert_equal policy_blocked(command, reason),
                     call(command, cwd: feature, home: home)
      end
    end

    def test_checking_out_a_branch_inside_a_linked_worktree_is_blocked
      with_backend_worktree do |feature, home|
        command = "git checkout other"
        reason =
          "uses git switch or checkout inside a linked worktree. Use EnterWorktree for another branch or git restore for files."

        assert_equal policy_blocked(command, reason),
                     call(command, cwd: feature, home: home)
      end
    end

    def test_pi_branch_switch_names_its_available_tool
      with_backend_worktree do |feature, home|
        command = "git switch other"
        reason =
          "uses git switch or checkout inside a linked worktree. Use enter_worktree for another branch or git restore for files."

        assert_equal policy_blocked(command, reason),
                     call(command, cwd: feature, home: home, host: "pi")
      end
    end

    def test_other_git_commands_inside_a_linked_worktree_are_allowed
      with_backend_worktree do |feature, home|
        assert_equal [0, ""],
                     call("git status --short", cwd: feature, home: home)
      end
    end

    def test_switching_a_main_checkout_from_a_linked_worktree_is_allowed
      with_backend_worktree do |feature, home|
        assert_equal [0, ""],
                     call(
                       "git -C ~/Code/backend switch other",
                       cwd: feature,
                       home: home
                     )
      end
    end

    def test_switching_another_linked_worktree_is_blocked
      with_two_backend_worktrees do |feature, _other, home|
        command = "git -C ~/Code/worktrees/backend/other switch feature"

        assert_branch_switch_blocked(command, cwd: feature, home: home)
      end
    end

    def test_home_variable_resolves_the_branch_switch_target
      with_two_backend_worktrees do |feature, _other, home|
        command = "git -C $HOME/Code/worktrees/backend/other switch feature"

        assert_branch_switch_blocked(command, cwd: feature, home: home)
      end
    end

    def test_relative_path_resolves_the_branch_switch_target
      with_two_backend_worktrees do |feature, _other, home|
        command = "git -C ../other switch feature"

        assert_branch_switch_blocked(command, cwd: feature, home: home)
      end
    end

    def test_switching_branches_inside_a_main_checkout_is_allowed
      with_repositories do |backend, home|
        assert_equal [0, ""], call("git switch other", cwd: backend, home: home)
      end
    end

    def test_checking_out_a_branch_inside_a_main_checkout_is_allowed
      with_repositories do |backend, home|
        assert_equal [0, ""],
                     call("git checkout other", cwd: backend, home: home)
      end
    end

    def test_dotfiles_worktree_from_main_checkout_is_blocked
      command = "git worktree add ../feature"
      reason =
        "adds a worktree to dotfiles. Edit dotfiles in its main checkout instead."

      assert_equal policy_blocked(command, reason),
                   call(command, cwd: "/Users/agent/Code/dotfiles")
    end

    def test_dotfiles_worktree_named_in_command_is_blocked
      command =
        "git -C ~/Code/backend/backend worktree add ~/Code/dotfiles/feature"
      reason =
        "adds a worktree to dotfiles. Edit dotfiles in its main checkout instead."

      assert_equal policy_blocked(command, reason), call(command)
    end

    def test_inline_merge_request_description_is_blocked
      command = "glab mr update 42 --description=ready"
      reason =
        "passes an MR description inline. Use mr-describe <iid> <file> to update one, or a shell script that reads the file to create one."

      assert_equal policy_blocked(command, reason), call(command)
    end

    def test_short_inline_merge_request_description_is_blocked
      command = "glab mr create -d ready"
      reason =
        "passes an MR description inline. Use mr-describe <iid> <file> to update one, or a shell script that reads the file to create one."

      assert_equal policy_blocked(command, reason), call(command)
    end

    def test_separate_inline_merge_request_description_is_blocked
      command = "glab mr update 42 --description ready"
      reason =
        "passes an MR description inline. Use mr-describe <iid> <file> to update one, or a shell script that reads the file to create one."

      assert_equal policy_blocked(command, reason), call(command)
    end

    def test_issue_description_is_not_treated_as_an_mr_description
      assert_equal [0, ""], call("glab issue update 42 --description ready")
    end

    def test_merge_request_view_is_not_treated_as_an_update
      assert_equal [0, ""], call("glab mr view 42 --description")
    end

    def test_plain_force_push_is_blocked
      command = "git push --force origin feature"

      assert_equal policy_blocked(
                     command,
                     "is a force push. Use --force-with-lease after an amend or rebase on a feature branch."
                   ),
                   call(command)
    end

    def test_force_push_after_an_unspaced_pipe_is_blocked
      command = "printf ready|git push --force origin feature"

      assert_equal policy_blocked(
                     command,
                     "is a force push. Use --force-with-lease after an amend or rebase on a feature branch."
                   ),
                   call(command)
    end

    def test_environment_prefixed_force_push_is_blocked
      command = "env GIT_TRACE=1 git push --force origin feature"

      assert_equal policy_blocked(
                     command,
                     "is a force push. Use --force-with-lease after an amend or rebase on a feature branch."
                   ),
                   call(command)
    end

    def test_force_push_with_a_quoted_repository_path_is_blocked
      command = "git -C '/tmp/repository path' push --force origin feature"

      assert_equal policy_blocked(
                     command,
                     "is a force push. Use --force-with-lease after an amend or rebase on a feature branch."
                   ),
                   call(command)
    end

    def test_short_force_push_is_blocked
      command = "git push -f origin feature"

      assert_equal policy_blocked(
                     command,
                     "is a force push. Use --force-with-lease after an amend or rebase on a feature branch."
                   ),
                   call(command)
    end

    def test_combined_short_force_push_is_blocked
      command = "git push -vf origin feature"

      assert_equal policy_blocked(
                     command,
                     "is a force push. Use --force-with-lease after an amend or rebase on a feature branch."
                   ),
                   call(command)
    end

    def test_force_with_lease_is_allowed
      assert_equal [0, ""], call("git push --force-with-lease origin feature")
    end

    def test_push_to_main_is_blocked
      command = "git push origin HEAD:main"

      assert_equal needs_go(command, "pushes a protected branch."),
                   call(command)
    end

    def test_push_of_local_main_is_blocked
      command = "git push origin main"

      assert_equal needs_go(command, "pushes a protected branch."),
                   call(command)
    end

    def test_push_to_main_after_go_is_allowed
      with_session do |home, session|
        command = "git push origin main"
        assert_equal needs_go(command, "pushes a protected branch."),
                     call(command, home: home, session_id: session)

        prompt(home, session, "go")

        assert_equal [0, ""], call(command, home: home, session_id: session)
      end
    end

    def test_restore_all_after_go_is_allowed
      with_session do |home, session|
        call("git restore .", home: home, session_id: session)
        prompt(home, session, "go")

        assert_equal [0, ""],
                     call("git restore .", home: home, session_id: session)
      end
    end

    def test_hard_reset_after_go_is_allowed
      with_session do |home, session|
        command = "git reset --hard origin/main"
        call(command, home: home, session_id: session)
        prompt(home, session, "go")

        assert_equal [0, ""], call(command, home: home, session_id: session)
      end
    end

    def test_go_typed_before_the_block_does_not_allow_a_push_to_main
      with_session do |home, session|
        command = "git push origin main"
        prompt(home, session, "go")

        assert_equal needs_go(command, "pushes a protected branch."),
                     call(command, home: home, session_id: session)
        assert_equal needs_go(command, "pushes a protected branch."),
                     call(command, home: home, session_id: session)
      end
    end

    def test_go_allows_only_the_blocked_command
      with_session do |home, session|
        call("git push origin main", home: home, session_id: session)
        prompt(home, session, "go")
        command = "git reset --hard HEAD~1"
        expected =
          "BLOCKED: '#{command}' matches dangerous pattern 'git reset --hard'. Ask the user for exact 'go', then retry unchanged.\n"

        assert_equal [2, expected],
                     call(command, home: home, session_id: session)
      end
    end

    def test_go_is_spent_by_the_retried_command
      with_session do |home, session|
        command = "git push origin main"
        call(command, home: home, session_id: session)
        prompt(home, session, "go")
        call(command, home: home, session_id: session)

        assert_equal needs_go(command, "pushes a protected branch."),
                     call(command, home: home, session_id: session)
      end
    end

    def test_other_prompt_does_not_allow_a_hard_reset
      with_session do |home, session|
        command = "git reset --hard origin/main"
        call(command, home: home, session_id: session)
        prompt(home, session, "go ahead")
        expected =
          "BLOCKED: '#{command}' matches dangerous pattern 'git reset --hard'. Ask the user for exact 'go', then retry unchanged.\n"

        assert_equal [2, expected],
                     call(command, home: home, session_id: session)
      end
    end

    def test_go_without_a_session_is_not_remembered
      Dir.mktmpdir do |home|
        command = "git push origin main"
        call(command, home: home)
        prompt(home, nil, "go")

        assert_equal needs_go(command, "pushes a protected branch."),
                     call(command, home: home)
      end
    end

    def test_go_still_guards_a_force_push_after_a_discard
      with_session do |home, session|
        command = "git restore . && git push --force origin feature"
        call(command, home: home, session_id: session)
        prompt(home, session, "go")

        assert_equal policy_blocked(command, FORCE_PUSH_REASON),
                     call(command, home: home, session_id: session)
      end
    end

    def test_go_does_not_allow_a_force_push
      with_session do |home, session|
        command = "git push --force origin feature"
        prompt(home, session, "go")

        assert_equal policy_blocked(command, FORCE_PUSH_REASON),
                     call(command, home: home, session_id: session)
      end
    end

    def test_go_still_guards_later_commands_in_a_chain
      with_session do |home, session|
        command = "git push origin main && git push --force origin feature"
        call(command, home: home, session_id: session)
        prompt(home, session, "go")

        assert_equal policy_blocked(command, FORCE_PUSH_REASON),
                     call(command, home: home, session_id: session)
      end
    end

    def test_branch_ending_in_main_is_allowed
      assert_equal [0, ""], call("git push origin domain")
    end

    def test_feature_push_is_allowed
      assert_equal [0, ""], call("git push origin feature")
    end

    def test_soft_reset_is_allowed
      assert_equal [0, ""], call("git reset --soft HEAD")
    end

    def test_clean_without_force_is_allowed
      assert_equal [0, ""], call("git clean -d")
    end

    def test_checkout_of_one_file_is_allowed
      assert_equal [0, ""], call("git checkout file.rb")
    end

    def test_restore_of_one_file_is_allowed
      assert_equal [0, ""], call("git restore file.rb")
    end

    def test_unrelated_reset_subcommand_is_allowed
      assert_equal [0, ""], call("tool reset --soft")
    end

    def test_unrelated_hard_option_is_allowed
      assert_equal [0, ""], call("tool hard --hard")
    end

    {
      "hard reset" => ["git reset --hard HEAD~1", "git reset --hard"],
      "clean directories" => ["git clean -fd", "git clean -fd"],
      "clean files" => ["git clean -f", "git clean -f"],
      "checkout all" => ["git checkout .", "git checkout \\."],
      "restore all" => ["git restore .", "git restore \\."],
      "nested reset" => ["tool reset --hard", "reset --hard"]
    }.each do |name, (command, pattern)|
      define_method("test_#{name.tr(" ", "_")}_is_blocked") do
        expected =
          "BLOCKED: '#{command}' matches dangerous pattern '#{pattern}'. Ask the user for exact 'go', then retry unchanged.\n"

        assert_equal [2, expected], call(command)
      end
    end

    def test_clean_with_other_arguments_is_blocked
      command = "git clean -fd ignored"
      expected =
        "BLOCKED: '#{command}' matches dangerous pattern 'git clean -fd'. Ask the user for exact 'go', then retry unchanged.\n"

      assert_equal [2, expected], call(command)
    end

    def test_commit_cannot_skip_hooks
      command = "git commit --no-verify -F /tmp/message"
      reason =
        "skips commit hooks with --no-verify. Fix what the hooks report, then commit again."

      assert_equal policy_blocked(command, reason), call(command)
    end

    def test_noncommit_no_verify_option_is_allowed
      assert_equal [0, ""], call("git fetch --no-verify")
    end

    def test_plain_push_outside_a_repository_is_allowed
      Dir.mktmpdir do |directory|
        assert_equal [0, ""], call("git push", cwd: directory)
      end
    end

    def test_dotfiles_cwd_does_not_block_unrelated_command
      assert_equal [0, ""],
                   call("git status", cwd: "/Users/agent/Code/dotfiles")
    end

    def test_dotfiles_cwd_allows_worktree_listing
      assert_equal [0, ""],
                   call("git worktree list", cwd: "/Users/agent/Code/dotfiles")
    end

    def test_dotfiles_cwd_allows_other_add_subcommands
      assert_equal [0, ""],
                   call("git branch add", cwd: "/Users/agent/Code/dotfiles")
    end

    def test_dotfiles_worktree_under_worktrees_directory_is_blocked
      command = "git worktree add ~/worktrees/dotfiles/feature"
      reason =
        "adds a worktree to dotfiles. Edit dotfiles in its main checkout instead."

      assert_equal policy_blocked(command, reason), call(command)
    end

    def test_dotfiles_worktree_from_subdirectory_is_blocked
      command = "git worktree add ../feature"
      reason =
        "adds a worktree to dotfiles. Edit dotfiles in its main checkout instead."

      assert_equal policy_blocked(command, reason),
                   call(command, cwd: "/Users/agent/Code/dotfiles/modules")
    end

    def test_plain_push_from_main_is_blocked
      with_repository("backend", branch: "main") do |root, home|
        assert_equal needs_go("git push", "pushes a protected branch."),
                     call("git push", cwd: root, home: home)
      end
    end

    def test_plain_push_from_a_feature_branch_is_allowed
      with_repository("backend", branch: "feature") do |root, home|
        assert_equal [0, ""], call("git push", cwd: root, home: home)
      end
    end

    def test_main_branch_can_push_an_explicit_feature_ref
      with_repository("backend", branch: "main") do |root, home|
        assert_equal [0, ""],
                     call("git push origin feature", cwd: root, home: home)
        assert_equal [0, ""],
                     call(
                       "git push --porcelain origin feature",
                       cwd: root,
                       home: home
                     )
      end
    end

    def test_main_branch_cannot_push_implicitly_to_an_explicit_remote
      with_repository("backend", branch: "main") do |root, home|
        command = "git push origin"
        assert_equal needs_go(command, "pushes a protected branch."),
                     call(command, cwd: root, home: home)

        command = "git push --porcelain origin"
        assert_equal needs_go(command, "pushes a protected branch."),
                     call(command, cwd: root, home: home)
      end
    end

    def test_chattermill_pushes_main_directly
      with_repository("chattermill", branch: "main") do |root, home|
        assert_equal [0, ""], call("git push", cwd: root, home: home)
        assert_equal [0, ""],
                     call("git push origin main", cwd: root, home: home)
      end
    end

    def test_chattermill_does_not_push_master
      with_repository("chattermill", branch: "master") do |root, home|
        assert_equal needs_go(
                       "git push origin master",
                       "pushes a protected branch."
                     ),
                     call("git push origin master", cwd: root, home: home)
      end
    end

    def test_push_to_master_ref_is_blocked
      command = "git push origin HEAD:refs/heads/master"

      assert_equal needs_go(command, "pushes a protected branch."),
                   call(command)
    end

    def test_worktree_outside_dotfiles_is_left_to_the_worktree_policy
      assert_equal blocked, call("git worktree add ../feature")
    end

    def test_description_file_is_not_an_inline_description
      with_session do |home, session|
        change_writing(home, session)

        assert_equal [0, ""],
                     call(
                       "glab mr update 42 --description-file /tmp/description",
                       home: home,
                       session_id: session
                     )
      end
    end

    def test_commit_without_no_verify_is_allowed
      with_session do |home, session|
        change_writing(home, session)
        with_commit_message("Document hook policy\n\nExplain why.\n") do |path|
          assert_equal [0, ""],
                       call(
                         "git commit -F #{path}",
                         home: home,
                         session_id: session
                       )
        end
      end
    end

    private

    def with_two_backend_worktrees
      with_backend_worktree do |feature, home|
        other = "#{home}/Code/worktrees/backend/other"
        git(
          "-C",
          "#{home}/Code/backend",
          "worktree",
          "add",
          "--quiet",
          "-b",
          "other",
          other
        )
        yield feature, other, home
      end
    end

    def assert_branch_switch_blocked(command, cwd:, home:)
      reason =
        "uses git switch or checkout inside a linked worktree. Use EnterWorktree for another branch or git restore for files."
      assert_equal policy_blocked(command, reason),
                   call(command, cwd: cwd, home: home)
    end
  end
end
