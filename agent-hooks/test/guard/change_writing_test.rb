require_relative "../support/guard_helpers"

module AgentHooks
  class ChangeWritingPolicyTest < Minitest::Test
    include GuardHelpers
    cover "AgentHooks::Guard::Policies::ChangeWriting*"
    cover "AgentHooks::Guard::Policies.evaluate"
    cover "AgentHooks::Guard::Facts*"

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

    def test_change_writing_allows_commit
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

    def test_change_writing_allows_description_update
      with_session do |home, session|
        change_writing(home, session)

        assert_equal [0, ""],
                     call(
                       "mr-describe 42 /tmp/mr-description.md",
                       home: home,
                       session_id: session
                     )
      end
    end

    def test_description_written_after_change_writing_is_stale
      with_session do |home, session|
        change_writing(home, session)
        observe(home, session, "Write", file_path: "/tmp/mr-description.md")

        assert_equal [2, CHANGE_WRITING_MESSAGE],
                     call(
                       "printf ready && mr-describe 42 /tmp/mr-description.md && printf done",
                       home: home,
                       session_id: session
                     )
      end
    end

    def test_description_edited_after_change_writing_is_stale
      with_session do |home, session|
        change_writing(home, session)
        observe(home, session, "Edit", file_path: "/tmp/mr-description.md")

        assert_equal [2, CHANGE_WRITING_MESSAGE],
                     call(
                       "mr-describe 42 /tmp/mr-description.md",
                       home: home,
                       session_id: session
                     )
      end
    end

    def test_relative_description_path_resolves_against_the_working_directory
      with_session do |home, session|
        change_writing(home, session)
        observe(
          home,
          session,
          "Edit",
          file_path: "#{home}/repo/mr-description.md"
        )

        assert_equal [2, CHANGE_WRITING_MESSAGE],
                     call(
                       "mr-describe 42 mr-description.md",
                       cwd: "#{home}/repo",
                       home: home,
                       session_id: session
                     )
      end
    end

    def test_change_writing_after_the_latest_description_edit_is_current
      with_session do |home, session|
        observe(home, session, "Edit", file_path: "/tmp/mr-description.md")
        change_writing(home, session)

        assert_equal [0, ""],
                     call(
                       "mr-describe 42 /tmp/mr-description.md",
                       home: home,
                       session_id: session
                     )
      end
    end

    def test_other_file_edits_do_not_stale_change_writing
      with_session do |home, session|
        change_writing(home, session)
        observe(home, session, "Write", file_path: "/tmp/notes.md")

        assert_equal [0, ""],
                     call(
                       "mr-describe 42 /tmp/mr-description.md",
                       home: home,
                       session_id: session
                     )
      end
    end

    def test_named_description_file_is_checked_even_without_a_description_name
      with_session do |home, session|
        change_writing(home, session)
        observe(home, session, "Edit", file_path: "/tmp/notes.md")

        assert_equal [2, CHANGE_WRITING_MESSAGE],
                     call(
                       "mr-describe 42 /tmp/notes.md",
                       home: home,
                       session_id: session
                     )
      end
    end

    def test_only_the_named_description_file_counts_for_an_update
      with_session do |home, session|
        change_writing(home, session)
        observe(home, session, "Edit", file_path: "/tmp/mr-description.md")

        assert_equal [0, ""],
                     call(
                       "mr-describe 42 /tmp/notes.md",
                       home: home,
                       session_id: session
                     )
      end
    end

    def test_description_update_without_a_file_falls_back_to_the_pattern
      with_session do |home, session|
        change_writing(home, session)
        observe(home, session, "Edit", file_path: "/tmp/notes.md")

        assert_equal [0, ""],
                     call(
                       "gh pr create --title Ready && mr-describe 42",
                       home: home,
                       session_id: session
                     )
      end
    end

    def test_description_directory_name_does_not_stale_creation
      with_session do |home, session|
        change_writing(home, session)
        observe(home, session, "Edit", file_path: "/tmp/desc/notes.md")

        assert_equal [0, ""],
                     call(
                       "gh pr create --title Ready",
                       home: home,
                       session_id: session
                     )
      end
    end

    def test_one_description_edit_among_others_stales_creation
      with_session do |home, session|
        change_writing(home, session)
        observe(home, session, "Edit", file_path: "/tmp/notes.md")
        observe(home, session, "Write", file_path: "/tmp/mr-description.md")
        observe(home, session, "Edit", file_path: "/tmp/README.md")

        assert_equal [2, CHANGE_WRITING_MESSAGE],
                     call(
                       "gh pr create --title Ready",
                       home: home,
                       session_id: session
                     )
      end
    end

    def test_recorded_facts_other_than_true_do_not_count
      with_session do |home, session|
        change_writing(home, session)
        File.write(
          facts_file(home, session),
          JSON.generate("change_writing" => "yes")
        )

        assert_equal [2, CHANGE_WRITING_MESSAGE],
                     call(
                       "git commit -F /tmp/message",
                       home: home,
                       session_id: session
                     )
      end
    end

    def test_skill_result_without_a_name_is_ignored
      with_session do |home, session|
        observe(home, session, "Skill")

        assert_equal [2, CHANGE_WRITING_MESSAGE],
                     call(
                       "git commit -F /tmp/message",
                       home: home,
                       session_id: session
                     )
      end
    end

    def test_earlier_edits_stay_stale_after_later_edits
      with_session do |home, session|
        change_writing(home, session)
        observe(home, session, "Edit", file_path: "/tmp/mr-description.md")
        observe(home, session, "Edit", file_path: "/tmp/notes.md")

        assert_equal [2, CHANGE_WRITING_MESSAGE],
                     call(
                       "mr-describe 42 /tmp/mr-description.md",
                       home: home,
                       session_id: session
                     )
      end
    end

    def test_any_description_edit_stales_merge_request_creation
      with_session do |home, session|
        change_writing(home, session)
        observe(home, session, "Edit", file_path: "/tmp/MR-Description.md")

        assert_equal [2, CHANGE_WRITING_MESSAGE],
                     call(
                       "gh pr create --title Ready",
                       home: home,
                       session_id: session
                     )
      end
    end

    def test_description_outside_markdown_does_not_stale_creation
      with_session do |home, session|
        change_writing(home, session)
        observe(home, session, "Edit", file_path: "/tmp/description.txt")

        assert_equal [0, ""],
                     call(
                       "gh pr create --title Ready",
                       home: home,
                       session_id: session
                     )
      end
    end

    def test_description_edit_does_not_stale_commit
      with_session do |home, session|
        change_writing(home, session)
        observe(home, session, "Edit", file_path: "/tmp/mr-description.md")

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

    def test_change_writing_allows_artifact_publish
      with_session do |home, session|
        change_writing(home, session)

        assert_equal [0, ""],
                     artifact(action: "publish", home: home, session: session)
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

    def test_change_writing_allows_linear_publication
      with_session do |home, session|
        change_writing(home, session)

        assert_equal [0, ""],
                     guarded_tool(
                       "mcp__linear__save_document",
                       { content: "Decision" },
                       home: home,
                       session: session
                     )
      end
    end

    def test_change_writing_without_a_session_is_not_remembered
      Dir.mktmpdir do |home|
        change_writing(home, nil)

        assert_equal [2, CHANGE_WRITING_MESSAGE],
                     call("git commit -F /tmp/message", home: home)
      end
    end

    def test_other_skills_do_not_count_as_change_writing
      with_session do |home, session|
        observe(home, session, "Skill", skill: "commit")

        assert_equal [2, CHANGE_WRITING_MESSAGE],
                     call(
                       "git commit -F /tmp/message",
                       home: home,
                       session_id: session
                     )
      end
    end

    def test_other_tool_results_do_not_count_as_change_writing
      with_session do |home, session|
        observe(home, session, "Read", file_path: "/tmp/SKILL.md")

        assert_equal [2, CHANGE_WRITING_MESSAGE],
                     call(
                       "git commit -F /tmp/message",
                       home: home,
                       session_id: session
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

    def test_script_that_creates_an_mr_is_stale_after_a_description_edit
      with_session do |home, session|
        File.write("#{home}/publish.sh", "glab mr create --title ready\n")
        change_writing(home, session)
        observe(home, session, "Edit", file_path: "#{home}/mr-description.md")

        assert_equal [2, CHANGE_WRITING_MESSAGE],
                     call(
                       "./publish.sh",
                       cwd: home,
                       home: home,
                       session_id: session
                     )
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

    def test_merge_request_description_file_requires_change_writing
      assert_equal [2, CHANGE_WRITING_MESSAGE],
                   call("glab mr update 42 --description-file /tmp/description")
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

    def test_fixup_commit_does_not_require_change_writing
      assert_equal [0, ""], call("git commit --fixup abc123")
    end

    def test_no_edit_commit_does_not_require_change_writing
      assert_equal [0, ""], call("git commit --amend --no-edit")
    end

    def test_other_git_commands_do_not_require_change_writing
      assert_equal [0, ""], call("git status")
    end

    def test_assignment_only_command_does_not_require_change_writing
      assert_equal [0, ""], call("FOO=bar")
    end
  end
end
