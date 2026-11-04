require_relative "../support/guard_helpers"

module AgentHooks
  class AttributionPolicyTest < Minitest::Test
    include GuardHelpers
    cover "AgentHooks::Guard::Policies::Attribution*"
    cover "AgentHooks::Guard::Policies.evaluate"

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
  end
end
