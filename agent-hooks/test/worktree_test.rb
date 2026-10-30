require "minitest/autorun"
require "mutant/minitest/coverage"
require "agent_hooks/worktree"
require_relative "support/worktree_harness"

module AgentHooks
  class WorktreeTest < Minitest::Test
    include WorktreeHarness

    cover "AgentHooks::Worktree*"

    WEEK = 7 * 24 * 60 * 60

    def setup
      setup_worktree_harness
    end

    def teardown
      teardown_worktree_harness
    end

    def test_new_branch_is_created_from_the_origin_default_branch
      main = "#{@home}/Code/backend"
      FileUtils.mkdir_p("#{main}/.git")

      result = run_worktree_source(
        {hook_event_name: "WorktreeCreate", name: "arrow  26", cwd: main},
        "GIT_COMMON_DIR" => "#{main}/.git"
      )

      destination = "#{@home}/Code/worktrees/backend/arrow--26"
      assert_equal({status: 0, stdout: "#{destination}\n", stderr: ""}, result)
      assert_equal(
        [
          "-C #{main} rev-parse --path-format=absolute --git-common-dir",
          "-C #{main} symbolic-ref --quiet refs/remotes/origin/HEAD",
          "-C #{main} show-ref --verify --quiet refs/heads/arrow  26",
          "-C #{main} worktree add -b arrow  26 #{destination} origin/main"
        ],
        git_log
      )
      assert_empty devenv_log
    end

    def test_existing_branch_is_checked_out_without_a_new_base
      main = "#{@home}/Code/backend"
      FileUtils.mkdir_p("#{main}/.git")

      result = run_worktree_source(
        {hook_event_name: "WorktreeCreate", name: "feature", cwd: main},
        "GIT_COMMON_DIR" => "#{main}/.git",
        "GIT_BRANCH_EXISTS" => "1"
      )

      destination = "#{@home}/Code/worktrees/backend/feature"
      assert_equal 0, result[:status]
      assert_equal "-C #{main} worktree add #{destination} feature", git_log.last
    end

    def test_head_is_used_when_origin_has_no_default_branch
      main = "#{@home}/Code/backend"
      FileUtils.mkdir_p("#{main}/.git")

      result = run_worktree_source(
        {hook_event_name: "WorktreeCreate", name: "feature", cwd: main},
        "GIT_COMMON_DIR" => "#{main}/.git",
        "GIT_ORIGIN_STATUS" => "1"
      )

      assert_equal 0, result[:status]
      assert_includes git_log, "-C #{main} remote set-head origin --auto"
      assert_equal "-C #{main} worktree add -b feature #{@home}/Code/worktrees/backend/feature HEAD", git_log.last
    end

    def test_origin_default_branch_is_retried_after_refresh
      main = "#{@home}/Code/backend"
      FileUtils.mkdir_p("#{main}/.git")

      result = run_worktree_source(
        {hook_event_name: "WorktreeCreate", name: "feature", cwd: main},
        "GIT_COMMON_DIR" => "#{main}/.git",
        "GIT_ORIGIN_RECOVER" => "1",
        "GIT_ORIGIN_HEAD" => "refs/remotes/origin/trunk"
      )

      assert_equal 0, result[:status]
      assert_equal ["-C #{main} symbolic-ref --quiet refs/remotes/origin/HEAD"] * 2,
        git_log.select { |command| command.include?("symbolic-ref") }
      assert_equal "-C #{main} worktree add -b feature #{@home}/Code/worktrees/backend/feature origin/trunk", git_log.last
    end

    def test_dotfiles_worktree_is_rejected
      main = "#{@home}/Code/dotfiles"
      FileUtils.mkdir_p("#{main}/.git")

      result = run_worktree_source(
        {hook_event_name: "WorktreeCreate", name: "feature", cwd: main},
        "GIT_COMMON_DIR" => "#{main}/.git"
      )

      assert_equal({status: 1, stdout: "", stderr: "dotfiles is edited in its main checkout, never in a linked worktree.\n"}, result)
    end

    def test_missing_repository_is_reported_without_git_noise
      result = nil
      process_output = capture_subprocess_io do
        result = run_worktree_source(
          {hook_event_name: "WorktreeCreate", name: "feature", cwd: "/missing"},
          "GIT_COMMON_STATUS" => "1"
        )
      end

      assert_equal ["", ""], process_output
      assert_equal({status: 1, stdout: "", stderr: "Could not find the repository for /missing\n"}, result)
    end

    def test_existing_destination_is_reported
      main = "#{@home}/Code/backend"
      destination = "#{@home}/Code/worktrees/backend/feature"
      FileUtils.mkdir_p(["#{main}/.git", destination])

      result = run_worktree_source(
        {hook_event_name: "WorktreeCreate", name: "feature", cwd: main},
        "GIT_COMMON_DIR" => "#{main}/.git"
      )

      assert_equal({status: 1, stdout: "", stderr: "Worktree path already exists: #{destination}\n"}, result)
    end

    def test_git_creation_failure_is_returned
      main = "#{@home}/Code/backend"
      FileUtils.mkdir_p("#{main}/.git")

      result = run_worktree_source(
        {hook_event_name: "WorktreeCreate", name: "feature", cwd: main},
        "GIT_COMMON_DIR" => "#{main}/.git",
        "GIT_WORKTREE_STATUS" => "1"
      )

      assert_equal({status: 1, stdout: "", stderr: "worktree failed\n"}, result)
    end

    def test_devenv_allow_failure_warns_but_keeps_the_created_worktree
      main = "#{@home}/Code/backend"
      FileUtils.mkdir_p("#{main}/.git")

      result = nil
      process_output = capture_subprocess_io do
        result = run_worktree_source(
          {hook_event_name: "WorktreeCreate", name: "feature", cwd: main},
          "GIT_COMMON_DIR" => "#{main}/.git",
          "CREATE_DEVENV_NIX" => "1",
          "DEVENV_ALLOW_STATUS" => "1"
        )
      end

      destination = "#{@home}/Code/worktrees/backend/feature"
      assert_equal ["", ""], process_output
      assert_equal 0, result[:status]
      assert_equal "#{destination}\n", result[:stdout]
      assert_equal "allow command failed\ndevenv allow failed for #{destination}; run it there before using devenv.\n", result[:stderr]
      assert_equal ["#{destination} allow"], devenv_log
    end

    def test_devenv_allow_runs_in_the_created_worktree
      main = "#{@home}/Code/backend"
      FileUtils.mkdir_p("#{main}/.git")

      result = run_worktree_source(
        {hook_event_name: "WorktreeCreate", name: "feature", cwd: main},
        "GIT_COMMON_DIR" => "#{main}/.git",
        "CREATE_DEVENV_NIX" => "1"
      )

      destination = "#{@home}/Code/worktrees/backend/feature"
      assert_equal({status: 0, stdout: "#{destination}\n", stderr: ""}, result)
      assert_equal ["#{destination} allow"], devenv_log
    end

    def test_successful_devenv_start_is_owned_by_the_session
      root = managed_root
      observe("one", root, at: 1)

      finished = finish("one", at: 2)
      retried = heartbeat("other", at: 3)

      assert_equal "", finished[:stderr]
      assert_equal "", retried[:stderr]
      assert_includes git_log, "-C #{root} rev-parse --show-toplevel"
      assert_equal ["#{root} down"], devenv_log
    end

    def test_main_checkout_devenv_is_not_owned
      root = "#{@home}/Code/backend"
      FileUtils.mkdir_p(root)

      observe("one", root, at: 1)
      finish("one", at: 2)

      assert_empty devenv_log
    end

    def test_shared_worktree_stops_after_its_last_owner_leaves
      root = managed_root
      observe("one", root, at: 1)
      observe("two", root, at: 2)

      finish("one", at: 3)
      assert_empty devenv_log

      finish("two", at: 4)
      assert_equal ["#{root} down"], devenv_log
    end

    def test_concurrent_starts_preserve_both_owners
      roots = [managed_root("one"), managed_root("two")]
      reader, writer = IO.pipe
      pids = roots.each_with_index.map do |root, index|
        fork do
          writer.close
          reader.read(1)
          environment = worktree_environment(
            "GIT_ROOT" => root,
            "GIT_ROOT_DELAY" => "0.2"
          )
          event = {
            "hook_event_name" => "PostToolUse",
            "session_id" => (index + 1).to_s,
            "cwd" => root,
            "tool_input" => {"command" => "devenv up"}
          }
          status = nil
          with_environment(environment) do
            status = AgentHooks::Worktree.run(
              event,
              out: StringIO.new,
              err: StringIO.new,
              env: environment,
              now: 1
            )
          end
          exit! status
        end
      end
      reader.close
      writer.write("xx")
      writer.close
      pids.each { |pid| Process.wait(pid) }

      finish("1", at: 2)
      finish("2", at: 3)

      assert_equal roots.map { |root| "#{root} down" }.sort, devenv_log.sort
    end

    def test_repeated_start_by_one_session_has_one_ownership
      root = managed_root
      observe("one", root, at: 1)
      observe("one", root, at: 2)

      finish("one", at: 3)

      assert_equal ["#{root} down"], devenv_log
    end

    def test_non_devenv_result_refreshes_existing_ownership
      root = managed_root
      observe("one", root, at: 1)

      post("one", root, "git status", at: WEEK)
      heartbeat("other", at: WEEK + 2)

      assert_empty devenv_log
    end

    def test_non_devenv_result_does_not_claim_a_worktree
      root = managed_root

      post("one", root, "git status", at: 1)
      finish("one", at: 2)

      assert_empty devenv_log
    end

    def test_failed_root_lookup_does_not_claim_a_worktree
      root = managed_root

      result = post("one", root, "devenv up", at: 1, extra: {"GIT_ROOT_STATUS" => "1"})
      finish("one", at: 2)

      assert_equal 0, result[:status]
      assert_empty devenv_log
    end

    def test_post_tool_use_expires_other_idle_owners
      old_root = managed_root("old")
      active_root = managed_root("active")
      observe("old", old_root, at: 1)
      observe("active", active_root, at: 2)

      post("active", active_root, "git status", at: WEEK + 2)

      assert_equal ["#{old_root} down"], devenv_log
    end

    def test_current_owner_is_refreshed_before_expiry
      root = managed_root
      observe("one", root, at: 1)

      heartbeat("one", at: WEEK + 2)

      assert_empty devenv_log
    end

    def test_expired_owner_is_removed_without_stopping_an_active_owner
      root = managed_root
      observe("old", root, at: 1)
      observe("active", root, at: 2)

      heartbeat("active", at: WEEK + 2)
      finish("active", at: WEEK + 3)

      assert_equal ["#{root} down"], devenv_log
    end

    def test_expired_last_owner_stops_devenv
      root = managed_root
      started_at = 10 * WEEK
      observe("old", root, at: started_at)

      heartbeat("new", at: started_at + WEEK + 2)

      assert_equal ["#{root} down"], devenv_log
    end

    def test_failed_stop_remains_pending_and_retries
      root = managed_root
      observe("one", root, at: 1)

      first = finish("one", at: 2, extra: {"DEVENV_DOWN_RESULT" => "failure"})
      second = heartbeat("other", at: 3, extra: {"DEVENV_DOWN_RESULT" => "failure"})
      third = post("other", root, "git status", at: 4, extra: {"DEVENV_DOWN_RESULT" => "failure"})

      message = "Failed to stop devenv processes for #{root}: process manager failed\n"
      assert_equal message, first[:stderr]
      assert_equal message, second[:stderr]
      assert_equal message, third[:stderr]

      heartbeat("other", at: 5)
      assert_equal ["#{root} down"] * 4, devenv_log
    end

    def test_already_stopped_devenv_clears_pending_cleanup
      root = managed_root
      observe("one", root, at: 1)

      finish("one", at: 2, extra: {"DEVENV_DOWN_RESULT" => "missing"})
      heartbeat("other", at: 3)

      assert_equal ["#{root} down"], devenv_log
    end

    def test_missing_worktree_clears_pending_cleanup
      root = managed_root
      observe("one", root, at: 1)
      FileUtils.rm_rf(root)

      finish("one", at: 2)
      FileUtils.mkdir_p(root)
      heartbeat("other", at: 3)

      assert_empty devenv_log
    end

    def test_legacy_ownership_state_is_migrated
      root = managed_root
      write_legacy_state(
        "sessions" => {"one" => [root]},
        "roots" => {root => ["one"]},
        "seen" => {"one" => 1}
      )

      finish("one", at: 2)

      assert_equal ["#{root} down"], devenv_log
    end

    def test_legacy_timestamp_keeps_recent_ownership_active
      root = managed_root
      write_legacy_state(
        "sessions" => {"one" => [root]},
        "roots" => {root => ["one"]},
        "seen" => {"one" => WEEK}
      )

      heartbeat("other", at: WEEK + 2)
      assert_empty devenv_log

      finish("one", at: WEEK + 3)
      assert_equal ["#{root} down"], devenv_log
    end

    def test_failed_tool_event_does_not_claim_devenv
      root = managed_root

      run_worktree_source(
        {hook_event_name: "PostToolUseFailure", session_id: "one", cwd: root, tool_input: {command: "devenv up -d"}},
        "GIT_ROOT" => root,
        now: Time.at(1)
      )
      finish("one", at: 2)

      assert_empty devenv_log
    end

    def test_lifecycle_events_return_success
      root = managed_root

      started = observe("one", root, at: 1)
      refreshed = heartbeat("one", at: 2)
      finished = finish("one", at: 3)

      assert_equal 0, started[:status]
      assert_equal 0, refreshed[:status]
      assert_equal 0, finished[:status]
    end

    def test_non_bash_post_tool_use_refreshes_existing_ownership
      root = managed_root
      observe("one", root, at: 1)

      result = run_worktree_source(
        {hook_event_name: "PostToolUse", session_id: "one", tool_input: {path: "/tmp/file"}},
        now: Time.at(WEEK)
      )
      heartbeat("other", at: WEEK + 2)

      assert_equal 0, result[:status]
      assert_empty devenv_log
    end

    def test_post_tool_use_without_an_identifier_is_ignored
      result = run_worktree_source(
        {hook_event_name: "PostToolUse", tool_input: {command: "devenv up"}, cwd: managed_root}
      )

      assert_equal({status: 0, stdout: "", stderr: ""}, result)
      refute File.exist?(state_file)
    end

    def test_heartbeat_without_an_identifier_is_ignored
      result = run_worktree_source({hook_event_name: "Heartbeat"})

      assert_equal({status: 0, stdout: "", stderr: ""}, result)
      refute File.exist?(state_file)
    end

    def test_session_end_without_an_identifier_is_ignored
      result = run_worktree_source({hook_event_name: "SessionEnd"})

      assert_equal({status: 0, stdout: "", stderr: ""}, result)
      refute File.exist?(state_file)
    end

    def test_session_start_refreshes_existing_ownership
      root = managed_root
      observe("one", root, at: 1)

      lifecycle("SessionStart", "one", at: WEEK)
      heartbeat("other", at: WEEK + 2)

      assert_empty devenv_log
    end

    def test_user_prompt_refreshes_existing_ownership
      root = managed_root
      observe("one", root, at: 1)

      lifecycle("UserPromptSubmit", "one", at: WEEK)
      heartbeat("other", at: WEEK + 2)

      assert_empty devenv_log
    end

    def test_home_state_directory_is_used_without_xdg_state
      result = run_worktree_source(
        {hook_event_name: "Heartbeat", session_id: "one"},
        xdg_state: false
      )

      directory = "#{@home}/.local/state/agent-worktree"
      assert_equal 0, result[:status]
      assert File.file?("#{directory}/state.json")
      refute File.exist?("#{@tmp}/HOME/.local/state/agent-worktree/state.json")
      assert_equal 0o600, File.stat("#{directory}/lock").mode & 0o777
    end

    def test_state_directory_failure_preserves_the_filesystem_error
      blocked = "#{@tmp}/blocked"
      File.write(blocked, "not a directory")
      environment = worktree_environment("XDG_STATE_HOME" => blocked)

      error = assert_raises(Errno::EEXIST) do
        AgentHooks::Worktree.run(
          {"hook_event_name" => "Heartbeat", "session_id" => "one"},
          env: environment,
          out: StringIO.new,
          err: StringIO.new,
          now: 1
        )
      end

      assert_includes error.message, blocked
    end

    def test_unknown_event_has_no_effect
      result = run_worktree_source({hook_event_name: "Unknown", session_id: "one"})

      assert_equal({status: 0, stdout: "", stderr: ""}, result)
      refute File.exist?(state_file)
    end

    private

    def observe(session, root, at: Time.now.to_i)
      run_worktree_source(
        {hook_event_name: "PostToolUse", session_id: session, cwd: root, tool_input: {command: "devenv up -d"}},
        {"GIT_ROOT" => root},
        now: Time.at(at)
      )
    end

    def post(session, root, command, at: Time.now.to_i, extra: {})
      run_worktree_source(
        {hook_event_name: "PostToolUse", session_id: session, cwd: root, tool_input: {command: command}},
        {"GIT_ROOT" => root}.merge(extra),
        now: Time.at(at)
      )
    end

    def heartbeat(session, at: Time.now.to_i, extra: {})
      run_worktree_source(
        {hook_event_name: "Heartbeat", session_id: session},
        extra,
        now: Time.at(at)
      )
    end

    def lifecycle(name, session, at: Time.now.to_i)
      run_worktree_source(
        {hook_event_name: name, session_id: session},
        now: Time.at(at)
      )
    end

    def state_file
      "#{@state}/agent-worktree/state.json"
    end

    def finish(session, at: Time.now.to_i, extra: {})
      run_worktree_source(
        {hook_event_name: "SessionEnd", session_id: session},
        extra,
        now: Time.at(at)
      )
    end
  end
end
