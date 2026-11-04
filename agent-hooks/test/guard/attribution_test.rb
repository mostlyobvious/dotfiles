require_relative "../support/guard_helpers"

module AgentHooks
  class AttributionPolicyTest < Minitest::Test
    include GuardHelpers
    cover "AgentHooks::Guard::Policies::Attribution*"
    cover "AgentHooks::Guard::Policies.evaluate"

    TRAILER = "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
    FOOTER = "Generated with [Claude Code](https://claude.com/claude-code)"

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

    def test_commit_without_attribution_is_allowed
      with_commit_message("Document hook policy\n\nExplain why.\n") do |path|
        assert_equal [0, ""],
                     call("git commit -F #{path}", change_writing: true)
      end
    end

    def test_trailer_inside_the_message_file_is_blocked
      with_commit_message("Document hook policy\n\n#{TRAILER}\n") do |path|
        assert_equal [2, ATTRIBUTION_MESSAGE],
                     call("git commit -F #{path}", change_writing: true)
      end
    end

    def test_footer_inside_the_message_file_is_blocked
      with_commit_message("Document hook policy\n\n#{FOOTER}\n") do |path|
        assert_equal [2, ATTRIBUTION_MESSAGE],
                     call("git commit -F #{path}", change_writing: true)
      end
    end

    def test_relative_message_file_resolves_against_the_working_directory
      Dir.mktmpdir do |directory|
        File.write(
          "#{directory}/message",
          "Document hook policy\n\n#{TRAILER}\n"
        )

        assert_equal [2, ATTRIBUTION_MESSAGE],
                     call(
                       "git commit -F message",
                       cwd: directory,
                       change_writing: true
                     )
      end
    end

    def test_dangling_message_file_option_is_allowed
      assert_equal [0, ""], call("git commit --no-edit -F")
    end

    def test_message_file_after_other_options_is_still_read
      with_commit_message("Document hook policy\n\n#{TRAILER}\n") do |path|
        assert_equal [2, ATTRIBUTION_MESSAGE],
                     call("git commit --quiet -F #{path}", change_writing: true)
      end
    end

    def test_reading_a_file_that_credits_claude_is_allowed
      with_commit_message("Document hook policy\n\n#{TRAILER}\n") do |path|
        assert_equal [0, ""], call("cat #{path}")
      end
    end

    def test_assignment_only_command_is_allowed
      assert_equal [0, ""], call("FOO=bar")
    end

    def test_footer_in_a_described_merge_request_is_blocked
      Dir.mktmpdir do |directory|
        description = "#{directory}/mr-description.md"
        File.write(description, "## Why\n\n#{FOOTER}\n")

        assert_equal [2, ATTRIBUTION_MESSAGE],
                     call("mr-describe 42 #{description}", change_writing: true)
      end
    end

    def test_trailer_in_a_description_file_option_is_blocked
      Dir.mktmpdir do |directory|
        description = "#{directory}/mr-description.md"
        File.write(description, "## Why\n\n#{TRAILER}\n")

        assert_equal [2, ATTRIBUTION_MESSAGE],
                     call(
                       "glab mr update 42 --description-file #{description}",
                       change_writing: true
                     )
      end
    end

    def test_trailer_in_an_attached_description_file_option_is_blocked
      Dir.mktmpdir do |directory|
        description = "#{directory}/mr-description.md"
        File.write(description, "## Why\n\n#{TRAILER}\n")

        assert_equal [2, ATTRIBUTION_MESSAGE],
                     call(
                       "glab mr update 42 --description-file=#{description}",
                       change_writing: true
                     )
      end
    end

    def test_dangling_description_file_option_is_allowed
      assert_equal [0, ""],
                   call(
                     "glab mr update 42 --description-file",
                     change_writing: true
                   )
    end

    def test_description_file_read_by_a_script_is_blocked
      Dir.mktmpdir do |directory|
        File.write("#{directory}/mr-description.md", "## Why\n\n#{FOOTER}\n")
        File.write(
          "#{directory}/publish.sh",
          "glab mr create --squash-before-merge=false --description-file mr-description.md\n"
        )

        assert_equal [2, ATTRIBUTION_MESSAGE],
                     call("./publish.sh", cwd: directory, change_writing: true)
      end
    end

    def test_script_without_sh_suffix_is_not_inspected
      Dir.mktmpdir do |directory|
        File.write("#{directory}/mr-description.md", FOOTER)
        File.write(
          "#{directory}/publish",
          "glab mr update 42 --description-file mr-description.md\n"
        )

        assert_equal [0, ""],
                     call("./publish", cwd: directory, change_writing: true)
      end
    end

    def test_missing_script_is_allowed
      assert_equal [0, ""], call("./missing.sh", change_writing: true)
    end

    def test_clean_description_file_is_allowed
      Dir.mktmpdir do |directory|
        description = "#{directory}/mr-description.md"
        File.write(description, "## Why\n\nExplain why.\n")

        assert_equal [0, ""],
                     call("mr-describe 42 #{description}", change_writing: true)
      end
    end

    def test_missing_description_file_is_allowed
      assert_equal [0, ""],
                   call("mr-describe 42 /tmp/missing.md", change_writing: true)
    end
  end
end
