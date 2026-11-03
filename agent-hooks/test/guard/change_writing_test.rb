require_relative "../support/guard_helpers"

module AgentHooks
  class ChangeWritingPolicyTest < Minitest::Test
    include GuardHelpers
    cover "AgentHooks::Guard::Policies::ChangeWriting*"
    cover "AgentHooks::Guard::Policies.evaluate"

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
