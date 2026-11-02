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
      "BLOCKED: commit messages, MR/PR descriptions, artifacts, and Linear prose require reading and applying change-writing/SKILL.md first.\n"
    MR_REMINDER =
      "If the pushed branch has an open MR, compare its description with the new diff and propose an update when they disagree (merge-request skill, step 8)."
    REVIEW_REMINDER =
      "Run the change-writing Review Pass on mr-description.md before presenting it for approval (merge-request skill, step 6)."
    WORKTREE_MESSAGE =
      "BLOCKED: create worktrees through the session host so every command starts in the worktree.\n"

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
                     "BLOCKED: this session runs in /tmp/repository. Start or move the session to #{target} so every command starts there, then rerun without the cd.\n"
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
                     "BLOCKED: this session runs in /tmp/repository. Start or move the session to #{target} so every command starts there, then rerun without the cd.\n"
                   ],
                   call(command)
    end

    def test_current_worktree_does_not_hide_a_later_worktree_transition
      target = "/Users/agent/Code/worktrees/backend/other"
      command =
        "cd ~/Code/worktrees/backend/feature && cd ~/Code/worktrees/backend/other"

      assert_equal [
                     2,
                     "BLOCKED: this session runs in /Users/agent/Code/worktrees/backend/feature. Start or move the session to #{target} so every command starts there, then rerun without the cd.\n"
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
                     "BLOCKED: this session runs in /tmp/repository. Start or move the session to #{target} so every command starts there, then rerun without the cd.\n"
                   ],
                   call(command)
    end

    def test_regular_cd_does_not_hide_a_later_worktree_transition
      target = "/Users/agent/Code/worktrees/backend/feature"
      command = "cd /tmp && cd ~/Code/worktrees/backend/feature"

      assert_equal [
                     2,
                     "BLOCKED: this session runs in /tmp/repository. Start or move the session to #{target} so every command starts there, then rerun without the cd.\n"
                   ],
                   call(command)
    end

    def test_worktree_repository_cd_does_not_hide_a_later_transition
      target = "/Users/agent/Code/worktrees/backend/feature"
      command =
        "cd ~/Code/worktrees/backend && cd ~/Code/worktrees/backend/feature"

      assert_equal [
                     2,
                     "BLOCKED: this session runs in /tmp/repository. Start or move the session to #{target} so every command starts there, then rerun without the cd.\n"
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
                     "BLOCKED: this session runs in /tmp/repository. Start or move the session to #{target} so every command starts there, then rerun without the cd.\n"
                   ],
                   call("cd $HOME/Code/worktrees/backend/feature")
    end

    def test_worktree_subdirectory_names_the_worktree_root
      target = "/Users/agent/Code/worktrees/backend/feature"

      assert_equal [
                     2,
                     "BLOCKED: this session runs in /tmp/repository. Start or move the session to #{target} so every command starts there, then rerun without the cd.\n"
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

      assert_equal policy_blocked(command, "pushes a protected branch."),
                   call(command)
    end

    def test_push_of_local_main_is_blocked
      command = "git push origin main"

      assert_equal policy_blocked(command, "pushes a protected branch."),
                   call(command)
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
          "BLOCKED: '#{command}' matches dangerous pattern '#{pattern}'. The user has prevented you from doing this.\n"

        assert_equal [2, expected], call(command)
      end
    end

    def test_clean_with_other_arguments_is_blocked
      command = "git clean -fd ignored"
      expected =
        "BLOCKED: '#{command}' matches dangerous pattern 'git clean -fd'. The user has prevented you from doing this.\n"

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

    def test_fixup_commit_keeps_its_message
      assert_equal [0, ""], call("git commit --fixup HEAD")
    end

    def test_no_edit_commit_keeps_its_message
      assert_equal [0, ""], call("git commit --no-edit")
    end

    def test_applied_change_writing_allows_commit
      assert_equal [0, ""],
                   call(
                     "git commit -F /tmp/message",
                     change_writing_applied: true
                   )
    end

    def test_transcript_with_change_writing_allows_commit
      Dir.mktmpdir do |directory|
        transcript = "#{directory}/transcript"
        File.write(transcript, "# Change Writing\n")

        assert_equal [0, ""],
                     call(
                       "git commit -F /tmp/message",
                       transcript_path: transcript
                     )
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

    def test_push_to_master_ref_is_blocked
      command = "git push origin HEAD:refs/heads/master"

      assert_equal policy_blocked(command, "pushes a protected branch."),
                   call(command)
    end

    def test_each_command_in_a_chain_is_guarded
      command = "git push origin feature && git reset --hard"

      expected =
        "BLOCKED: '#{command}' matches dangerous pattern 'git reset --hard'. The user has prevented you from doing this.\n"

      assert_equal [2, expected], call(command)
    end

    def test_quoted_dangerous_command_is_plain_text
      assert_equal [0, ""], call("printf 'git reset --hard'")
    end

    def test_dynamic_shell_command_is_blocked_when_it_cannot_be_inspected
      command = 'printf "$(date)"'
      message =
        "BLOCKED: agent-guard cannot inspect this shell syntax safely. Put the command in a reviewed script and run that script.\n"

      assert_equal [2, message], call(command)
    end

    def test_unclosed_quote_is_blocked_when_it_cannot_be_inspected
      command = "printf 'unfinished"
      message =
        "BLOCKED: agent-guard cannot inspect this shell syntax safely. Put the command in a reviewed script and run that script.\n"

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
                     "BLOCKED: this session runs in /tmp. Start or move the session to #{target} so every command starts there, then rerun without the cd.\n",
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

    def blocked
      [2, WORKTREE_MESSAGE]
    end

    def policy_blocked(command, reason)
      [
        2,
        "BLOCKED: '#{command}' #{reason} The user has prevented you from doing this.\n"
      ]
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
  end
end
