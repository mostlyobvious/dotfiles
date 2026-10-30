require "minitest/autorun"
require_relative "support/guard_runner"

class AgentGuardPolicyTest < Minitest::Test
  include GuardRunner

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

  private

  def assert_blocked(command)
    result = run_guard(command)

    assert_equal 2, result[:status]
    assert_equal "", result[:stdout]
    assert_equal "BLOCKED: '#{command}' edits files through an in-place shell command. Use Edit for existing files or Write for new files and complete rewrites.\n", result[:stderr]
  end
end
