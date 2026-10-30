require "minitest/autorun"
require_relative "support/worktree_harness"

class AgentWorktreeTest < Minitest::Test
  include WorktreeHarness

  def setup
    setup_worktree_harness
  end

  def teardown
    teardown_worktree_harness
  end

  def test_native_worktree_creation_matches_the_process_interface
    main = "#{@home}/Code/backend"
    FileUtils.mkdir_p("#{main}/.git")

    result = run_worktree_process(
      {hook_event_name: "WorktreeCreate", name: "feature", cwd: main},
      "GIT_COMMON_DIR" => "#{main}/.git"
    )

    assert_equal 0, result[:status]
    assert_equal "#{@home}/Code/worktrees/backend/feature\n", result[:stdout]
    assert_equal "", result[:stderr]
  end

  def test_native_session_lifecycle_stops_owned_devenv
    root = managed_root

    started = run_worktree_process(
      {hook_event_name: "PostToolUse", session_id: "one", cwd: root, tool_input: {command: "devenv up -d"}},
      "GIT_ROOT" => root
    )
    finished = run_worktree_process(hook_event_name: "SessionEnd", session_id: "one")

    assert_equal 0, started[:status]
    assert_equal 0, finished[:status]
    assert_equal ["#{root} down"], devenv_log
  end
end
