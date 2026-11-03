require_relative "../support/guard_helpers"

module AgentHooks
  class CommitPolicyTest < Minitest::Test
    include GuardHelpers
    cover "AgentHooks::Guard::Policies::Commit*"
    cover "AgentHooks::Guard::Policies.evaluate"

    def test_commit_message_comes_from_a_file
      assert_equal [2, COMMIT_FILE_MESSAGE],
                   call("git commit -m ready", change_writing_applied: true)
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
  end
end
