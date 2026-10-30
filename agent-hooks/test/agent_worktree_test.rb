require "json"
require "minitest/autorun"
require "open3"
require "tmpdir"
require "fileutils"

class AgentWorktreeTest < Minitest::Test
  def setup
    @tmp = Dir.mktmpdir
    @home = "#{@tmp}/home"
    @state = "#{@tmp}/state"
    @bin = "#{@tmp}/bin"
    @git_log = "#{@tmp}/git.log"
    @devenv_log = "#{@tmp}/devenv.log"
    FileUtils.mkdir_p([@home, @state, @bin])
    write_fake_commands
  end

  def teardown
    FileUtils.rm_rf(@tmp)
  end

  def test_worktree_create_places_branch_under_managed_directory
    main = "#{@home}/Code/backend"
    FileUtils.mkdir_p("#{main}/.git")
    event = {hook_event_name: "WorktreeCreate", name: "arrow 26", cwd: main}

    result = run_worktree(event, "GIT_COMMON_DIR" => "#{main}/.git")

    assert_equal 0, result[:status]
    assert_equal "#{@home}/Code/worktrees/backend/arrow-26\n", result[:stdout]
    assert File.directory?("#{@home}/Code/worktrees/backend/arrow-26")
  end

  def test_dotfiles_worktree_is_rejected
    main = "#{@home}/Code/dotfiles"
    FileUtils.mkdir_p("#{main}/.git")

    result = run_worktree(
      {hook_event_name: "WorktreeCreate", name: "feature", cwd: main},
      "GIT_COMMON_DIR" => "#{main}/.git"
    )

    assert_equal 1, result[:status]
    assert_equal "dotfiles is edited in its main checkout, never in a linked worktree.\n", result[:stderr]
  end

  def test_shared_worktree_stops_after_its_last_session_ends
    root = managed_root
    observe("one", root)
    observe("two", root)

    finish("one")
    refute File.exist?(@devenv_log)

    finish("two")
    assert_equal "#{root} down\n", File.read(@devenv_log)
  end

  def test_failed_post_tool_event_does_not_claim_devenv
    root = managed_root
    event = {
      hook_event_name: "PostToolUseFailure",
      session_id: "one",
      cwd: root,
      tool_input: {command: "devenv up -d"}
    }

    assert_equal 0, run_worktree(event, "GIT_ROOT" => root)[:status]
    finish("one")
    refute File.exist?(@devenv_log)
  end

  def test_abandoned_session_is_released_after_a_week
    root = managed_root
    observe("old", root, "AGENT_WORKTREE_NOW" => "1")
    event = {
      hook_event_name: "PostToolUse",
      session_id: "new",
      cwd: root,
      tool_input: {command: "git status"}
    }

    run_worktree(event, "AGENT_WORKTREE_NOW" => (8 * 24 * 60 * 60).to_s)

    assert_equal "#{root} down\n", File.read(@devenv_log)
  end

  def test_devenv_in_main_checkout_is_not_owned
    root = "#{@home}/Code/backend"
    FileUtils.mkdir_p(root)

    observe("one", root)
    finish("one")

    refute File.exist?(@devenv_log)
  end

  private

  def managed_root
    root = "#{@home}/Code/worktrees/backend/feature"
    FileUtils.mkdir_p(root)
    root
  end

  def observe(session, root, extra = {})
    event = {
      hook_event_name: "PostToolUse",
      session_id: session,
      cwd: root,
      tool_input: {command: "devenv up -d"}
    }
    result = run_worktree(event, {"GIT_ROOT" => root}.merge(extra))
    assert_equal 0, result[:status]
  end

  def finish(session)
    result = run_worktree(hook_event_name: "SessionEnd", session_id: session)
    assert_equal 0, result[:status]
  end

  def run_worktree(event, extra = {})
    executable = ENV["AGENT_WORKTREE"]
    command = executable ? [executable] : [RbConfig.ruby, "-Ilib", "bin/agent-worktree"]
    environment = {
      "HOME" => @home,
      "XDG_STATE_HOME" => @state,
      "PATH" => "#{@bin}:#{ENV.fetch("PATH")}",
      "GIT_LOG" => @git_log,
      "DEVENV_LOG" => @devenv_log
    }.merge(extra)
    stdout, stderr, status = Open3.capture3(environment, *command, stdin_data: JSON.generate(event), chdir: File.expand_path("..", __dir__))
    {status: status.exitstatus, stdout: stdout, stderr: stderr}
  end

  def write_fake_commands
    write_executable("git", <<~SH)
      #!/bin/sh
      printf '%s\n' "$*" >> "$GIT_LOG"
      case "$*" in
        *"rev-parse --path-format=absolute --git-common-dir"*) printf '%s\n' "$GIT_COMMON_DIR" ;;
        *"rev-parse --show-toplevel"*) printf '%s\n' "$GIT_ROOT" ;;
        *"symbolic-ref --quiet refs/remotes/origin/HEAD"*) printf '%s\n' 'refs/remotes/origin/main' ;;
        *"show-ref --verify --quiet"*) exit 1 ;;
        *"worktree add"*)
          previous=
          for argument in "$@"; do destination=$previous; previous=$argument; done
          mkdir -p "$destination"
          ;;
      esac
    SH
    write_executable("devenv", <<~SH)
      #!/bin/sh
      printf '%s %s\n' "$PWD" "$*" >> "$DEVENV_LOG"
    SH
  end

  def write_executable(name, content)
    path = "#{@bin}/#{name}"
    File.write(path, content)
    FileUtils.chmod(0o755, path)
  end
end
