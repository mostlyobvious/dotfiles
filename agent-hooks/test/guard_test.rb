require "fileutils"
require "json"
require "minitest/autorun"
require "mutant/minitest/coverage"
require "tmpdir"
require_relative "../lib/agent_hooks/guard"

module AgentHooks
  class GuardTest < Minitest::Test
    cover "AgentHooks::Guard*"

    ATTRIBUTION_MESSAGE =
      "BLOCKED: commit messages must not include Anthropic or Claude co-author attribution.\n"
    CHANGE_WRITING_MESSAGE =
      "BLOCKED: commit messages, MR/PR descriptions, artifacts, and Linear prose require reading and applying change-writing/SKILL.md first. For an MR/PR description, apply it after the latest description edit.\n"
    MR_REMINDER =
      "If the pushed branch has an open MR, compare its description with the new diff and propose an update when they disagree (merge-request skill, step 8)."
    REVIEW_REMINDER =
      "Run the change-writing Review Pass on mr-description.md before presenting it for approval (merge-request skill, step 6)."
    WORKTREE_MESSAGE =
      "BLOCKED: use the session host's worktree tool (Claude Code: EnterWorktree) instead of git worktree add so every command starts in the worktree.\n"
    COMMIT_FILE_MESSAGE =
      "BLOCKED: write commit messages to a file and pass it with git commit -F.\n"
    COMMIT_FORMAT_MESSAGE =
      "BLOCKED: the commit message must have a capitalized subject of at most 50 characters without a trailing period, a blank line before its body, and body lines of at most 72 characters.\n"
    MR_SCRIPT_MESSAGE =
      "BLOCKED: open GitLab merge requests through a shell script that reads the approved description from a file.\n"
    MR_SQUASH_MESSAGE =
      "BLOCKED: GitLab merge request creation requires --squash-before-merge=false.\n"
    DEVENV_DETACH_MESSAGE =
      "BLOCKED: start worktree services with devenv up -d.\n"
    DEVENV_ROOT_MESSAGE = "BLOCKED: run devenv up -d from the worktree root.\n"

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

    def test_unrelated_git_command_is_allowed
      assert_equal [0, ""], call("git -C ~/Code/backend/backend status --short")
    end

    def test_environment_assignment_is_allowed
      assert_equal [0, ""], call("FOO=bar")
    end

    def test_worktree_list_is_allowed
      assert_equal [0, ""], call("git worktree list")
    end

    def test_other_command_with_add_argument_is_allowed
      assert_equal [0, ""], call("git branch add")
    end

    def test_non_git_worktree_command_is_allowed
      assert_equal [0, ""], call("worktree add feature")
    end

    def test_sed_short_in_place_option_is_blocked
      assert_equal shell_edit_blocked("sed -i '' 's/old/new/' file"),
                   call("sed -i '' 's/old/new/' file")
    end

    def test_sed_long_in_place_option_is_blocked
      command = "sed --in-place=.bak 's/old/new/' file"

      assert_equal shell_edit_blocked(command), call(command)
    end

    def test_sed_long_in_place_flag_is_blocked
      command = "sed --in-place 's/old/new/' file"

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

    def test_perl_bare_in_place_option_is_blocked
      command = "perl -i -e 's/old/new/' file"

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

      assert_equal [
                     2,
                     "BLOCKED: this session runs in /tmp/repository. Use the session host's worktree tool (Claude Code: EnterWorktree) with path #{target}, then rerun the command without cd.\n"
                   ],
                   call(
                     "cd ~/Code/worktrees/backend/feature && bundle exec rake"
                   )
    end

    def test_entering_a_worktree_later_in_a_command_chain_is_blocked
      target = "/Users/agent/Code/worktrees/backend/feature"
      command = "printf ready && cd ~/Code/worktrees/backend/feature"

      assert_equal [
                     2,
                     "BLOCKED: this session runs in /tmp/repository. Use the session host's worktree tool (Claude Code: EnterWorktree) with path #{target}, then rerun the command without cd.\n"
                   ],
                   call(command)
    end

    def test_current_worktree_does_not_hide_a_later_worktree_transition
      target = "/Users/agent/Code/worktrees/backend/other"
      command =
        "cd ~/Code/worktrees/backend/feature && cd ~/Code/worktrees/backend/other"

      assert_equal [
                     2,
                     "BLOCKED: this session runs in /Users/agent/Code/worktrees/backend/feature. Use the session host's worktree tool (Claude Code: EnterWorktree) with path #{target}, then rerun the command without cd.\n"
                   ],
                   call(
                     command,
                     cwd: "/Users/agent/Code/worktrees/backend/feature"
                   )
    end

    def test_entering_the_current_worktree_is_allowed
      assert_equal [0, ""],
                   call(
                     "cd $HOME/Code/worktrees/backend/feature && bundle exec rake",
                     cwd: "/Users/agent/Code/worktrees/backend/feature/app"
                   )
    end

    def test_entering_the_worktree_root_is_allowed
      assert_equal [0, ""],
                   call(
                     "cd ~/Code/worktrees/backend/feature",
                     cwd: "/Users/agent/Code/worktrees/backend/feature"
                   )
    end

    def test_entering_a_regular_directory_is_allowed
      assert_equal [0, ""],
                   call("cd ~/Code/backend/backend && bundle exec rake")
    end

    def test_cd_without_a_path_is_allowed
      assert_equal [0, ""], call("cd")
    end

    def test_cd_without_a_path_does_not_hide_a_later_worktree_transition
      target = "/Users/agent/Code/worktrees/backend/feature"
      command = "cd && cd ~/Code/worktrees/backend/feature"

      assert_equal [
                     2,
                     "BLOCKED: this session runs in /tmp/repository. Use the session host's worktree tool (Claude Code: EnterWorktree) with path #{target}, then rerun the command without cd.\n"
                   ],
                   call(command)
    end

    def test_regular_cd_does_not_hide_a_later_worktree_transition
      target = "/Users/agent/Code/worktrees/backend/feature"
      command = "cd /tmp && cd ~/Code/worktrees/backend/feature"

      assert_equal [
                     2,
                     "BLOCKED: this session runs in /tmp/repository. Use the session host's worktree tool (Claude Code: EnterWorktree) with path #{target}, then rerun the command without cd.\n"
                   ],
                   call(command)
    end

    def test_worktree_repository_cd_does_not_hide_a_later_transition
      target = "/Users/agent/Code/worktrees/backend/feature"
      command =
        "cd ~/Code/worktrees/backend && cd ~/Code/worktrees/backend/feature"

      assert_equal [
                     2,
                     "BLOCKED: this session runs in /tmp/repository. Use the session host's worktree tool (Claude Code: EnterWorktree) with path #{target}, then rerun the command without cd.\n"
                   ],
                   call(command)
    end

    def test_non_cd_command_with_a_worktree_path_is_allowed
      assert_equal [0, ""], call("printf ~/Code/worktrees/backend/feature")
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
      target = "/Users/agent/Code/worktrees/backend/feature"

      assert_equal [
                     2,
                     "BLOCKED: this session runs in /tmp/repository. Use the session host's worktree tool (Claude Code: EnterWorktree) with path #{target}, then rerun the command without cd.\n"
                   ],
                   call("cd $HOME/Code/worktrees/backend/feature")
    end

    def test_worktree_subdirectory_names_the_worktree_root
      target = "/Users/agent/Code/worktrees/backend/feature"

      assert_equal [
                     2,
                     "BLOCKED: this session runs in /tmp/repository. Use the session host's worktree tool (Claude Code: EnterWorktree) with path #{target}, then rerun the command without cd.\n"
                   ],
                   call("cd ~/Code/worktrees/backend/feature/app")
    end

    def test_dotfiles_worktree_from_main_checkout_is_blocked
      command = "git worktree add ../feature"
      reason =
        "adds a worktree to dotfiles, which is edited in its main checkout."

      assert_equal policy_blocked(command, reason),
                   call(command, cwd: "/Users/agent/Code/dotfiles")
    end

    def test_dotfiles_worktree_named_in_command_is_blocked
      command =
        "git -C ~/Code/backend/backend worktree add ~/Code/dotfiles/feature"
      reason =
        "adds a worktree to dotfiles, which is edited in its main checkout."

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

      assert_equal policy_blocked(command, "is a force push."), call(command)
    end

    def test_force_push_after_an_unspaced_pipe_is_blocked
      command = "printf ready|git push --force origin feature"

      assert_equal policy_blocked(command, "is a force push."), call(command)
    end

    def test_environment_prefixed_force_push_is_blocked
      command = "env GIT_TRACE=1 git push --force origin feature"

      assert_equal policy_blocked(command, "is a force push."), call(command)
    end

    def test_force_push_with_a_quoted_repository_path_is_blocked
      command = "git -C '/tmp/repository path' push --force origin feature"

      assert_equal policy_blocked(command, "is a force push."), call(command)
    end

    def test_short_force_push_is_blocked
      command = "git push -f origin feature"

      assert_equal policy_blocked(command, "is a force push."), call(command)
    end

    def test_combined_short_force_push_is_blocked
      command = "git push -vf origin feature"

      assert_equal policy_blocked(command, "is a force push."), call(command)
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
      Dir.mktmpdir do |directory|
        transcript = conversation(directory, "push it", "go", :tool_result)

        assert_equal [0, ""],
                     call("git push origin main", transcript_path: transcript)
      end
    end

    def test_restore_all_after_go_is_allowed
      Dir.mktmpdir do |directory|
        transcript =
          conversation(directory, "go", [:meta, "skill instructions"])

        assert_equal [0, ""], call("git restore .", transcript_path: transcript)
      end
    end

    def test_go_survives_assistant_replies_and_unreadable_lines
      Dir.mktmpdir do |directory|
        transcript =
          conversation(
            directory,
            "go",
            [:assistant, "pushing now"],
            [:meta, "skill instructions"],
            :unreadable
          )

        assert_equal [0, ""],
                     call("git push origin main", transcript_path: transcript)
      end
    end

    def test_transcript_without_a_typed_message_blocks_a_push_to_main
      Dir.mktmpdir do |directory|
        transcript = conversation(directory, :tool_result)
        command = "git push origin main"

        assert_equal needs_go(command, "pushes a protected branch."),
                     call(command, transcript_path: transcript)
      end
    end

    def test_go_still_guards_a_force_push_after_a_discard
      command = "git restore . && git push --force origin feature"

      assert_equal policy_blocked(command, "is a force push."),
                   call(command, last_user_text: "go")
    end

    def test_go_from_an_earlier_message_does_not_allow_a_push_to_main
      Dir.mktmpdir do |directory|
        transcript = conversation(directory, "go", "now push main")
        command = "git push origin main"

        assert_equal needs_go(command, "pushes a protected branch."),
                     call(command, transcript_path: transcript)
      end
    end

    def test_go_from_pi_allows_a_hard_reset
      assert_equal [0, ""],
                   call("git reset --hard origin/main", last_user_text: "go")
    end

    def test_other_pi_message_does_not_allow_a_hard_reset
      command = "git reset --hard origin/main"
      expected =
        "BLOCKED: '#{command}' matches dangerous pattern 'git reset --hard'. Ask the user for exact 'go', then retry unchanged.\n"

      assert_equal [2, expected], call(command, last_user_text: "go ahead")
    end

    def test_go_does_not_allow_a_force_push
      command = "git push --force origin feature"

      assert_equal policy_blocked(command, "is a force push."),
                   call(command, last_user_text: "go")
    end

    def test_go_still_guards_later_commands_in_a_chain
      command = "git push origin main && git push --force origin feature"

      assert_equal policy_blocked(command, "is a force push."),
                   call(command, last_user_text: "go")
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

    def test_commit_requires_change_writing
      assert_equal [2, CHANGE_WRITING_MESSAGE],
                   call("git commit -F /tmp/message")
    end

    def test_commit_in_a_command_chain_requires_change_writing
      command = "git status && git commit -F /tmp/message"

      assert_equal [2, CHANGE_WRITING_MESSAGE], call(command)
    end

    def test_merge_request_create_requires_change_writing
      assert_equal [2, CHANGE_WRITING_MESSAGE],
                   call("gh pr create --title ready")
    end

    def test_merge_request_description_update_requires_change_writing
      assert_equal [2, CHANGE_WRITING_MESSAGE],
                   call("mr-describe 42 /tmp/mr-description.md")
    end

    def test_change_writing_before_the_latest_description_write_is_stale
      Dir.mktmpdir do |directory|
        description = "#{directory}/mr-description.md"
        transcript =
          change_writing_transcript(directory, :applied, ["Write", description])

        assert_equal [2, CHANGE_WRITING_MESSAGE],
                     call(
                       "printf ready && mr-describe 42 #{description} && printf done",
                       transcript_path: transcript
                     )
      end
    end

    def test_change_writing_before_a_standard_description_write_is_stale
      Dir.mktmpdir do |directory|
        transcript =
          change_writing_transcript(
            directory,
            :applied,
            %w[Write mr-description.md]
          )

        assert_equal [2, CHANGE_WRITING_MESSAGE],
                     call(
                       "gh pr create --title Ready",
                       transcript_path: transcript
                     )
      end
    end

    def test_change_writing_before_the_latest_description_edit_is_stale
      Dir.mktmpdir do |directory|
        transcript =
          change_writing_transcript(
            directory,
            :applied,
            %w[Edit mr-description.md]
          )

        assert_equal [2, CHANGE_WRITING_MESSAGE],
                     call(
                       "mr-describe 42 mr-description.md",
                       transcript_path: transcript
                     )
      end
    end

    def test_other_file_edits_do_not_stale_change_writing
      Dir.mktmpdir do |directory|
        transcript =
          change_writing_transcript(directory, :applied, %w[Write notes.md])

        assert_equal [0, ""],
                     call(
                       "mr-describe 42 mr-description.md",
                       transcript_path: transcript
                     )
      end
    end

    def test_description_reads_do_not_stale_change_writing
      Dir.mktmpdir do |directory|
        transcript =
          change_writing_transcript(
            directory,
            :applied,
            %w[Read mr-description.md]
          )

        assert_equal [0, ""],
                     call(
                       "mr-describe 42 mr-description.md",
                       transcript_path: transcript
                     )
      end
    end

    def test_change_writing_after_the_latest_description_edit_is_current
      Dir.mktmpdir do |directory|
        description = "#{directory}/mr-description.md"
        transcript =
          change_writing_transcript(directory, ["Edit", description], :applied)

        assert_equal [0, ""],
                     call(
                       "mr-describe 42 #{description}",
                       transcript_path: transcript
                     )
      end
    end

    def test_artifact_publish_requires_change_writing
      assert_equal [2, CHANGE_WRITING_MESSAGE], artifact(action: "publish")
    end

    def test_artifact_default_action_requires_change_writing
      assert_equal [2, CHANGE_WRITING_MESSAGE],
                   artifact(file_path: "/tmp/report.html")
    end

    def test_artifact_read_is_allowed_without_change_writing
      assert_equal [0, ""], artifact(action: "read")
    end

    def test_other_publish_shaped_tool_input_is_allowed_without_change_writing
      assert_equal [0, ""], artifact(tool_name: "Other", action: "publish")
    end

    def test_applied_change_writing_allows_artifact_publish
      assert_equal [0, ""],
                   artifact(action: "publish", change_writing_applied: true)
    end

    def test_transcript_with_change_writing_allows_artifact_publish
      Dir.mktmpdir do |directory|
        transcript = "#{directory}/transcript"
        File.write(transcript, "# Change Writing\n")

        assert_equal [0, ""],
                     guarded_tool(
                       "Artifact",
                       { action: "publish" },
                       transcript_path: transcript
                     )
      end
    end

    def test_linear_issue_description_requires_change_writing
      assert_equal [2, CHANGE_WRITING_MESSAGE],
                   guarded_tool(
                     "mcp__claude_ai_Linear__save_issue",
                     { id: "APP-123", description: "Revised scope" }
                   )
    end

    def test_linear_comment_requires_change_writing
      assert_equal [2, CHANGE_WRITING_MESSAGE],
                   guarded_tool(
                     "mcp__claude_ai_Linear__save_comment",
                     { issue: "APP-123", body: "Ready for review" }
                   )
    end

    def test_linear_document_title_requires_change_writing
      assert_equal [2, CHANGE_WRITING_MESSAGE],
                   guarded_tool(
                     "mcp__linear__save_document",
                     { title: "Decision record" }
                   )
    end

    def test_linear_document_content_requires_change_writing
      assert_equal [2, CHANGE_WRITING_MESSAGE],
                   guarded_tool(
                     "mcp__linear__save_document",
                     { content: "Decision" }
                   )
    end

    def test_linear_diff_review_summary_requires_change_writing
      assert_equal [2, CHANGE_WRITING_MESSAGE],
                   guarded_tool(
                     "mcp__claude_ai_Linear__submit_diff_review",
                     { summary: "Ready to merge" }
                   )
    end

    def test_linear_metadata_update_does_not_require_change_writing
      assert_equal [0, ""],
                   guarded_tool(
                     "mcp__claude_ai_Linear__save_issue",
                     { id: "APP-123", assignee: "me" }
                   )
    end

    def test_non_linear_description_does_not_require_change_writing
      assert_equal [0, ""],
                   guarded_tool(
                     "mcp__other__save_issue",
                     { description: "Revised scope" }
                   )
    end

    def test_linear_read_does_not_require_change_writing
      assert_equal [0, ""],
                   guarded_tool(
                     "mcp__claude_ai_Linear__get_issue",
                     { id: "APP-123" }
                   )
    end

    def test_applied_change_writing_allows_linear_publication
      assert_equal [0, ""],
                   guarded_tool(
                     "mcp__linear__save_document",
                     { content: "Decision" },
                     change_writing_applied: true
                   )
    end

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

    def test_unrelated_up_command_in_a_worktree_is_allowed
      with_worktree do |root, home|
        assert_equal [0, ""], call("tool up", cwd: root, home: home)
      end
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

    def test_gitlab_merge_request_creation_runs_from_a_script
      assert_equal [2, MR_SCRIPT_MESSAGE],
                   call(
                     "glab mr create --squash-before-merge=false",
                     change_writing_applied: true
                   )
    end

    def test_gitlab_merge_request_script_disables_squash
      Dir.mktmpdir do |directory|
        File.write("#{directory}/publish.sh", "glab mr create\n")

        assert_equal [2, MR_SQUASH_MESSAGE],
                     call(
                       "./publish.sh",
                       cwd: directory,
                       change_writing_applied: true
                     )
      end
    end

    def test_gitlab_merge_request_script_with_squash_disabled_is_allowed
      Dir.mktmpdir do |directory|
        File.write(
          "#{directory}/publish.sh",
          "glab mr create --squash-before-merge=false\n"
        )

        assert_equal [0, ""],
                     call(
                       "./publish.sh",
                       cwd: directory,
                       change_writing_applied: true
                     )
      end
    end

    def test_gitlab_merge_request_script_after_another_command_is_guarded
      Dir.mktmpdir do |directory|
        File.write("#{directory}/publish.sh", "glab mr create\n")

        assert_equal [2, MR_SQUASH_MESSAGE],
                     call(
                       "printf ready && ./publish.sh",
                       cwd: directory,
                       change_writing_applied: true
                     )
      end
    end

    def test_missing_script_does_not_hide_a_later_merge_request_script
      Dir.mktmpdir do |directory|
        File.write("#{directory}/publish.sh", "glab mr create\n")

        assert_equal [2, MR_SQUASH_MESSAGE],
                     call(
                       "./missing.sh && ./publish.sh",
                       cwd: directory,
                       change_writing_applied: true
                     )
      end
    end

    def test_commit_message_comes_from_a_file
      assert_equal [2, COMMIT_FILE_MESSAGE],
                   call("git commit -m ready", change_writing_applied: true)
    end

    def test_commit_cannot_skip_hooks
      command = "git commit --no-verify -F /tmp/message"
      reason = "skips commit hooks with --no-verify."

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

    def test_well_formed_commit_message_is_allowed
      with_commit_message(
        "Document hook policy\n\nExplain why it changes.\n"
      ) do |path|
        assert_equal [0, ""],
                     call("git commit -F #{path}", change_writing_applied: true)
      end
    end

    def test_commit_message_path_can_be_relative_to_the_working_directory
      Dir.mktmpdir do |directory|
        File.write("#{directory}/message", "Document hook policy\n")

        assert_equal [0, ""],
                     call(
                       "git commit -F message",
                       cwd: directory,
                       change_writing_applied: true
                     )
      end
    end

    def test_commit_message_cannot_come_from_standard_input
      assert_equal [2, COMMIT_FILE_MESSAGE],
                   call("git commit -F -", change_writing_applied: true)
    end

    def test_commit_message_file_must_exist
      assert_equal [2, COMMIT_FILE_MESSAGE],
                   call(
                     "git commit -F /missing/message",
                     change_writing_applied: true
                   )
    end

    def test_commit_message_flag_requires_a_path
      assert_equal [2, COMMIT_FILE_MESSAGE],
                   call("git commit -F", change_writing_applied: true)
    end

    def test_commit_message_flag_can_follow_other_options
      with_commit_message("Document hook policy\n") do |path|
        assert_equal [0, ""],
                     call(
                       "git commit --allow-empty -F #{path}",
                       change_writing_applied: true
                     )
      end
    end

    def test_empty_commit_message_is_rejected
      with_commit_message("") do |path|
        assert_equal [2, COMMIT_FORMAT_MESSAGE],
                     call("git commit -F #{path}", change_writing_applied: true)
      end
    end

    def test_commit_message_accepts_length_boundaries
      with_commit_message("A#{"b" * 49}\n\n#{"c" * 72}\n") do |path|
        assert_equal [0, ""],
                     call("git commit -F #{path}", change_writing_applied: true)
      end
    end

    def test_commit_in_a_command_chain_uses_its_message_file
      with_commit_message("Document hook policy\n") do |path|
        assert_equal [0, ""],
                     call(
                       "git status && git commit -F #{path}",
                       change_writing_applied: true
                     )
      end
    end

    def test_commit_subject_starts_with_a_capital
      with_commit_message("document hook policy\n") do |path|
        assert_equal [2, COMMIT_FORMAT_MESSAGE],
                     call("git commit -F #{path}", change_writing_applied: true)
      end
    end

    def test_commit_subject_has_at_most_fifty_characters
      with_commit_message("A" * 51) do |path|
        assert_equal [2, COMMIT_FORMAT_MESSAGE],
                     call("git commit -F #{path}", change_writing_applied: true)
      end
    end

    def test_commit_subject_has_no_trailing_period
      with_commit_message("Document hook policy.\n") do |path|
        assert_equal [2, COMMIT_FORMAT_MESSAGE],
                     call("git commit -F #{path}", change_writing_applied: true)
      end
    end

    def test_commit_body_follows_a_blank_line
      with_commit_message(
        "Document hook policy\nExplain why it changes.\n"
      ) do |path|
        assert_equal [2, COMMIT_FORMAT_MESSAGE],
                     call("git commit -F #{path}", change_writing_applied: true)
      end
    end

    def test_commit_body_lines_have_at_most_seventy_two_characters
      with_commit_message("Document hook policy\n\n#{"A" * 73}\n") do |path|
        assert_equal [2, COMMIT_FORMAT_MESSAGE],
                     call("git commit -F #{path}", change_writing_applied: true)
      end
    end

    def test_every_commit_body_line_has_at_most_seventy_two_characters
      message = "Document hook policy\n\nShort line\n#{"A" * 73}\n"
      with_commit_message(message) do |path|
        assert_equal [2, COMMIT_FORMAT_MESSAGE],
                     call("git commit -F #{path}", change_writing_applied: true)
      end
    end

    def test_fixup_commit_keeps_its_message
      assert_equal [0, ""], call("git commit --fixup HEAD")
    end

    def test_no_edit_commit_keeps_its_message
      assert_equal [0, ""], call("git commit --no-edit")
    end

    def test_applied_change_writing_allows_commit
      with_commit_message("Document hook policy\n") do |path|
        assert_equal [0, ""],
                     call("git commit -F #{path}", change_writing_applied: true)
      end
    end

    def test_transcript_with_change_writing_allows_commit
      Dir.mktmpdir do |directory|
        transcript = "#{directory}/transcript"
        File.write(transcript, "# Change Writing\n")

        with_commit_message("Document hook policy\n") do |path|
          assert_equal [0, ""],
                       call(
                         "git commit -F #{path}",
                         transcript_path: transcript
                       )
        end
      end
    end

    def test_relative_script_that_creates_an_mr_requires_change_writing
      Dir.mktmpdir do |directory|
        File.write("#{directory}/publish.sh", "glab mr create --title ready\n")

        assert_equal [2, CHANGE_WRITING_MESSAGE],
                     call("./publish.sh", cwd: directory)
      end
    end

    def test_script_with_one_mr_command_requires_change_writing
      Dir.mktmpdir do |directory|
        File.write(
          "#{directory}/publish.sh",
          "printf ready\nglab mr create --title ready\n"
        )

        assert_equal [2, CHANGE_WRITING_MESSAGE],
                     call("./publish.sh", cwd: directory)
      end
    end

    def test_regular_script_is_allowed
      Dir.mktmpdir do |directory|
        File.write("#{directory}/check.sh", "make check\n")

        assert_equal [0, ""], call("./check.sh", cwd: directory)
      end
    end

    def test_non_shell_script_with_mr_command_is_allowed
      Dir.mktmpdir do |directory|
        File.write("#{directory}/publish", "glab mr create --title ready\n")

        assert_equal [0, ""], call("./publish", cwd: directory)
      end
    end

    def test_missing_script_is_allowed
      assert_equal [0, ""], call("./missing.sh")
    end

    def test_claude_coauthor_is_blocked
      command =
        "git commit --fixup HEAD -m 'Co-authored-by: Claude <bot@anthropic.com>'"

      assert_equal [2, ATTRIBUTION_MESSAGE], call(command)
    end

    def test_anthropic_before_coauthor_is_blocked
      command = "git commit --no-edit -m 'Anthropic bot Co-authored-by: Person'"

      assert_equal [2, ATTRIBUTION_MESSAGE], call(command)
    end

    def test_noncommit_attribution_text_is_allowed
      assert_equal [0, ""], call("printf 'Co-authored-by: Claude'")
    end

    def test_git_status_with_attribution_text_is_allowed
      assert_equal [0, ""], call("git status 'Co-authored-by: Claude'")
    end

    def test_commit_attribution_in_a_command_chain_is_blocked
      command = "git status && git commit --no-edit -m 'Co-authored-by: Claude'"

      assert_equal [2, ATTRIBUTION_MESSAGE], call(command)
    end

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
        "adds a worktree to dotfiles, which is edited in its main checkout."

      assert_equal policy_blocked(command, reason), call(command)
    end

    def test_dotfiles_worktree_from_subdirectory_is_blocked
      command = "git worktree add ../feature"
      reason =
        "adds a worktree to dotfiles, which is edited in its main checkout."

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

    def test_each_command_in_a_chain_is_guarded
      command = "git push origin feature && git reset --hard"

      expected =
        "BLOCKED: '#{command}' matches dangerous pattern 'git reset --hard'. Ask the user for exact 'go', then retry unchanged.\n"

      assert_equal [2, expected], call(command)
    end

    def test_quoted_dangerous_command_is_plain_text
      assert_equal [0, ""], call("printf 'git reset --hard'")
    end

    def test_dynamic_shell_command_is_blocked_when_it_cannot_be_inspected
      command = 'printf "$(date)"'
      message =
        "BLOCKED: agent-guard cannot inspect this shell syntax safely. Split it into static commands, or put it in a reviewed .sh file and run that file.\n"

      assert_equal [2, message], call(command)
    end

    def test_unclosed_quote_is_blocked_when_it_cannot_be_inspected
      command = "printf 'unfinished"
      message =
        "BLOCKED: agent-guard cannot inspect this shell syntax safely. Split it into static commands, or put it in a reviewed .sh file and run that file.\n"

      assert_equal [2, message], call(command)
    end

    def test_merge_request_description_file_requires_change_writing
      assert_equal [2, CHANGE_WRITING_MESSAGE],
                   call("glab mr update 42 --description-file /tmp/description")
    end

    def test_change_writing_false_still_blocks_commit
      assert_equal [2, CHANGE_WRITING_MESSAGE],
                   call(
                     "git commit -F /tmp/message",
                     change_writing_applied: false
                   )
    end

    def test_missing_transcript_still_blocks_commit
      assert_equal [2, CHANGE_WRITING_MESSAGE],
                   call(
                     "git commit -F /tmp/message",
                     transcript_path: "/missing"
                   )
    end

    def test_unread_transcript_still_blocks_commit
      Dir.mktmpdir do |directory|
        transcript = "#{directory}/transcript"
        File.write(transcript, "other skill\n")

        assert_equal [2, CHANGE_WRITING_MESSAGE],
                     call(
                       "git commit -F /tmp/message",
                       transcript_path: transcript
                     )
      end
    end

    def test_absolute_script_that_creates_an_mr_requires_change_writing
      Dir.mktmpdir do |directory|
        script = "#{directory}/publish.sh"
        File.write(script, "gh pr edit 42 --title ready\n")

        assert_equal [2, CHANGE_WRITING_MESSAGE], call(script)
      end
    end

    def test_home_script_that_creates_an_mr_requires_change_writing
      Dir.mktmpdir do |home|
        File.write("#{home}/publish.sh", "glab mr edit 42 --title ready\n")
        assert_equal [2, CHANGE_WRITING_MESSAGE],
                     call("~/publish.sh", cwd: "/tmp", home: home)
      end
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
      target = "/Users/agent/Code/worktrees/backend/feature"
      output =
        Guard.run(
          {
            "hook_event_name" => "PreToolUse",
            "tool_input" => {
              "command" => "cd ~/Code/worktrees/backend/feature"
            },
            "cwd" => "/tmp"
          },
          "/Users/agent"
        )

      assert_equal [
                     2,
                     "BLOCKED: this session runs in /tmp. Use the session host's worktree tool (Claude Code: EnterWorktree) with path #{target}, then rerun the command without cd.\n",
                     nil
                   ],
                   output
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

    private

    def artifact(
      tool_name: "Artifact",
      change_writing_applied: false,
      transcript_path: nil,
      **tool_input
    )
      guarded_tool(
        tool_name,
        tool_input,
        change_writing_applied: change_writing_applied,
        transcript_path: transcript_path
      )
    end

    def guarded_tool(
      tool_name,
      tool_input,
      change_writing_applied: false,
      transcript_path: nil
    )
      status, message, =
        Guard.run(
          {
            "hook_event_name" => "PreToolUse",
            "tool_name" => tool_name,
            "tool_input" => tool_input.transform_keys(&:to_s),
            "cwd" => "/tmp",
            "change_writing_applied" => change_writing_applied,
            "transcript_path" => transcript_path
          },
          "/Users/agent"
        )
      [status, message]
    end

    def with_repository(name, branch:)
      Dir.mktmpdir do |home|
        root = "#{home}/Code/#{name}"
        FileUtils.mkdir_p(root)
        system(
          "git",
          "init",
          "--quiet",
          "--initial-branch=#{branch}",
          root,
          out: File::NULL,
          err: File::NULL
        ) or raise "git init failed"
        yield root, home
      end
    end

    def with_worktree
      Dir.mktmpdir do |home|
        root = "#{home}/Code/worktrees/backend/feature"
        FileUtils.mkdir_p(root)
        system(
          "git",
          "init",
          "--quiet",
          "--initial-branch=feature",
          root,
          out: File::NULL,
          err: File::NULL
        ) or raise "git init failed"
        yield root, home
      end
    end

    def with_commit_message(message)
      Dir.mktmpdir do |directory|
        path = "#{directory}/message"
        File.write(path, message)
        yield path
      end
    end

    def blocked
      [2, WORKTREE_MESSAGE]
    end

    def policy_blocked(command, reason)
      [
        2,
        "BLOCKED: '#{command}' #{reason} The user has prevented you from doing this.\n"
      ]
    end

    def needs_go(command, reason)
      [
        2,
        "BLOCKED: '#{command}' #{reason} Ask the user for exact 'go', then retry unchanged.\n"
      ]
    end

    def conversation(directory, *messages)
      lines =
        messages.map do |message|
          case message
          in String
            JSON.generate(
              { type: "user", message: { role: "user", content: message } }
            )
          in :tool_result
            JSON.generate(
              {
                type: "user",
                message: {
                  role: "user",
                  content: [{ type: "tool_result", content: "ok" }]
                }
              }
            )
          in [:meta, text]
            JSON.generate(
              {
                type: "user",
                isMeta: true,
                message: {
                  role: "user",
                  content: text
                }
              }
            )
          in [:assistant, text]
            JSON.generate(
              {
                type: "assistant",
                message: {
                  role: "assistant",
                  content: text
                }
              }
            )
          in :unreadable
            "{"
          end
        end
      path = "#{directory}/conversation.jsonl"
      File.write(path, lines.join("\n"))
      path
    end

    def reminder(message)
      {
        "hookSpecificOutput" => {
          "hookEventName" => "PostToolUse",
          "additionalContext" => message
        }
      }
    end

    def shell_edit_blocked(command)
      [
        2,
        "BLOCKED: '#{command}' edits files through an in-place shell command. Use Edit for existing files or Write for new files and complete rewrites.\n"
      ]
    end

    def call(command, cwd: "/tmp/repository", home: "/Users/agent", **event)
      status, message, =
        Guard.run(
          {
            "hook_event_name" => "PreToolUse",
            "tool_input" => {
              "command" => command
            },
            "cwd" => cwd
          }.merge(event.transform_keys(&:to_s)),
          home
        )
      [status, message]
    end

    def change_writing_transcript(directory, *events)
      records =
        events.map do |event|
          if event == :applied
            { message: { content: "# Change Writing" } }
          else
            name, path = event
            {
              message: {
                content: [
                  { type: "tool_use", name: name, input: { file_path: path } }
                ]
              }
            }
          end
        end
      path = "#{directory}/transcript.jsonl"
      File.write(
        path,
        records.map { |record| JSON.generate(record) }.join("\n")
      )
      path
    end
  end
end
