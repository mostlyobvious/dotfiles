require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "stringio"
require "tmpdir"

module WorktreeHarness
  def setup_worktree_harness
    @tmp = File.realpath(Dir.mktmpdir)
    @home = "#{@tmp}/user-home"
    @state = "#{@tmp}/state"
    @bin = "#{@tmp}/bin"
    @git_log = "#{@tmp}/git.log"
    @devenv_log = "#{@tmp}/devenv.log"
    FileUtils.mkdir_p([@home, @state, @bin])
    write_fake_commands
  end

  def teardown_worktree_harness
    FileUtils.rm_rf(@tmp)
  end

  def managed_root(name = "feature")
    root = "#{@home}/Code/worktrees/backend/#{name}"
    FileUtils.mkdir_p(root)
    root
  end

  def worktree_environment(extra = {})
    {
      "HOME" => @home,
      "XDG_STATE_HOME" => @state,
      "PATH" => "#{@bin}:#{ENV.fetch("PATH")}",
      "GIT_LOG" => @git_log,
      "DEVENV_LOG" => @devenv_log,
      "GIT_ORIGIN_MARKER" => "#{@tmp}/origin-recovered"
    }.merge(extra)
  end

  def run_worktree_source(event, extra = nil, now: Time.now, xdg_state: true, **variables)
    environment = worktree_environment((extra || {}).merge(variables.transform_keys(&:to_s)))
    environment.delete("XDG_STATE_HOME") unless xdg_state
    stdout = StringIO.new
    stderr = StringIO.new
    status = nil

    with_environment(environment) do
      Dir.chdir(@tmp) do
        status = AgentHooks::Worktree.run(
          stringify(event),
          env: environment,
          out: stdout,
          err: stderr,
          now: now.to_i
        )
      end
    end

    {status: status, stdout: stdout.string, stderr: stderr.string}
  end

  def run_worktree_process(event, extra = {})
    executable = ENV["AGENT_WORKTREE"]
    command = executable ? [executable] : [RbConfig.ruby, "-Ilib", "bin/agent-worktree"]
    stdout, stderr, status = Open3.capture3(
      worktree_environment(extra),
      *command,
      stdin_data: JSON.generate(event),
      chdir: File.expand_path("../..", __dir__)
    )
    {status: status.exitstatus, stdout: stdout, stderr: stderr}
  end

  def git_log
    File.file?(@git_log) ? File.readlines(@git_log, chomp: true) : []
  end

  def devenv_log
    File.file?(@devenv_log) ? File.readlines(@devenv_log, chomp: true) : []
  end

  def write_legacy_state(state)
    directory = "#{@state}/agent-worktree"
    FileUtils.mkdir_p(directory)
    File.write("#{directory}/state.json", JSON.generate(state))
  end

  private

  def stringify(value)
    JSON.parse(JSON.generate(value))
  end

  def with_environment(environment)
    previous = environment.to_h { |key, _value| [key, ENV[key]] }
    environment.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| value ? ENV[key] = value : ENV.delete(key) }
  end

  def write_fake_commands
    write_executable("git", <<~SH)
      #!/bin/sh
      printf '%s\n' "$*" >> "$GIT_LOG"
      case "$*" in
        *"rev-parse --path-format=absolute --git-common-dir"*)
          if [ "${GIT_COMMON_STATUS:-0}" -ne 0 ]; then
            printf '%s\n' 'not a repository' >&2
            exit "$GIT_COMMON_STATUS"
          fi
          printf '%s\n' "$GIT_COMMON_DIR"
          ;;
        *"rev-parse --show-toplevel"*)
          [ -z "${GIT_ROOT_DELAY:-}" ] || sleep "$GIT_ROOT_DELAY"
          [ "${GIT_ROOT_STATUS:-0}" -eq 0 ] || exit "$GIT_ROOT_STATUS"
          printf '%s\n' "$GIT_ROOT"
          ;;
        *"symbolic-ref --quiet refs/remotes/origin/HEAD"*)
          if [ "${GIT_ORIGIN_RECOVER:-0}" -eq 1 ] && [ ! -e "$GIT_ORIGIN_MARKER" ]; then
            touch "$GIT_ORIGIN_MARKER"
            exit 1
          fi
          [ "${GIT_ORIGIN_STATUS:-0}" -eq 0 ] || exit "$GIT_ORIGIN_STATUS"
          printf '%s\n' "${GIT_ORIGIN_HEAD:-refs/remotes/origin/main}"
          ;;
        *"show-ref --verify --quiet"*)
          [ "${GIT_BRANCH_EXISTS:-0}" -eq 1 ]
          ;;
        *"worktree add"*)
          if [ "${GIT_WORKTREE_STATUS:-0}" -ne 0 ]; then
            printf '%s\n' 'worktree failed' >&2
            exit "$GIT_WORKTREE_STATUS"
          fi
          previous=
          for argument in "$@"; do destination=$previous; previous=$argument; done
          [ -d "$(dirname "$destination")" ] || { printf '%s\n' 'worktree parent missing' >&2; exit 1; }
          [ ! -e "$destination" ] || { printf '%s\n' 'worktree destination exists' >&2; exit 1; }
          mkdir "$destination"
          if [ "${CREATE_DEVENV_NIX:-0}" -eq 1 ]; then touch "$destination/devenv.nix"; fi
          ;;
      esac
    SH
    write_executable("devenv", <<~SH)
      #!/bin/sh
      printf '%s %s\n' "$PWD" "$*" >> "$DEVENV_LOG"
      case "$1" in
        allow)
          if [ "${DEVENV_ALLOW_STATUS:-0}" -ne 0 ]; then printf '%s\n' 'allow command failed' >&2; fi
          exit "${DEVENV_ALLOW_STATUS:-0}"
          ;;
        down)
          case "${DEVENV_DOWN_RESULT:-success}" in
            success) exit 0 ;;
            missing) printf '%s\n' 'No process manager is running' >&2; exit 1 ;;
            failure) printf '%s\n' 'process manager failed' >&2; exit 1 ;;
          esac
          ;;
      esac
    SH
  end

  def write_executable(name, content)
    path = "#{@bin}/#{name}"
    File.write(path, content)
    FileUtils.chmod(0o755, path)
  end
end
