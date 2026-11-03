require "minitest/autorun"
require_relative "support/guard_runner"

class AgentGuardPolicyTest < Minitest::Test
  include GuardRunner

  CHANGE_WRITING_MESSAGE =
    "BLOCKED: commit messages, MR/PR descriptions, artifacts, and Linear prose require reading and applying change-writing/SKILL.md first. For an MR/PR description, apply it after the latest description edit.\n"

  def test_sed_in_place_edit_is_blocked
    command = "sed -i '' 's/old/new/' file"

    assert_blocked command
  end

  def test_perl_in_place_edit_is_blocked
    command = "perl -pi -e 's/old/new/' file"

    assert_blocked command
  end

  def test_sed_that_writes_to_stdout_continues
    result = run_guard("sed 's/old/new/' file")

    assert_equal 0, result[:status]
    assert_equal "", result[:stdout]
    assert_equal "", result[:stderr]
  end

  def test_plain_force_push_is_blocked
    assert_message(
      "git push --force origin feature",
      "BLOCKED: 'git push --force origin feature' is a force push. The user has prevented you from doing this.\n"
    )
  end

  def test_commit_requires_change_writing
    assert_message("git commit -F /tmp/message", CHANGE_WRITING_MESSAGE)
  end

  def test_artifact_publish_requires_change_writing
    result =
      run_guard(
        nil,
        tool_name: "Artifact",
        tool_input: {
          action: "publish",
          file_path: "/tmp/report.html"
        }
      )

    assert_equal 2, result[:status]
    assert_equal "", result[:stdout]
    assert_equal CHANGE_WRITING_MESSAGE, result[:stderr]
  end

  def test_linear_description_requires_change_writing
    result =
      run_guard(
        nil,
        tool_name: "mcp__claude_ai_Linear__save_issue",
        tool_input: {
          id: "APP-123",
          description: "Revised scope"
        }
      )

    assert_equal 2, result[:status]
    assert_equal "", result[:stdout]
    assert_equal CHANGE_WRITING_MESSAGE, result[:stderr]
  end

  def test_claude_coauthor_is_blocked
    command =
      "git commit --fixup HEAD -m 'Co-authored-by: Claude <bot@anthropic.com>'"

    assert_message(
      command,
      "BLOCKED: commit messages must not include Anthropic or Claude co-author attribution.\n"
    )
  end

  def test_push_returns_merge_request_reminder
    result =
      run_guard("git push origin feature", hook_event_name: "PostToolUse")
    output = JSON.parse(result[:stdout])

    assert_equal 0, result[:status]
    assert_equal "If the pushed branch has an open MR, compare its description with the new diff and propose an update when they disagree (merge-request skill, step 8).",
                 output.fetch("hookSpecificOutput").fetch("additionalContext")
  end

  def test_description_write_returns_review_reminder
    result =
      run_guard(
        nil,
        hook_event_name: "PostToolUse",
        tool_input: {
          file_path: "/tmp/mr-description.md"
        }
      )
    output = JSON.parse(result[:stdout])

    assert_equal 0, result[:status]
    assert_equal "Run the change-writing Review Pass on mr-description.md before presenting it for approval (merge-request skill, step 6).",
                 output.fetch("hookSpecificOutput").fetch("additionalContext")
  end

  private

  def assert_message(command, message)
    result = run_guard(command)

    assert_equal 2, result[:status]
    assert_equal "", result[:stdout]
    assert_equal message, result[:stderr]
  end

  def assert_blocked(command)
    result = run_guard(command)

    assert_equal 2, result[:status]
    assert_equal "", result[:stdout]
    assert_equal "BLOCKED: '#{command}' edits files through an in-place shell command. Use Edit for existing files or Write for new files and complete rewrites.\n",
                 result[:stderr]
  end
end
