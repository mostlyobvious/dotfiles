require "json"
require "open3"
require "pathname"
require "rbconfig"
require "minitest/autorun"

class AgentGuardTest < Minitest::Test
  ROOT = Pathname(__dir__).join("..").expand_path
  GUARD = if ENV["AGENT_GUARD"]
    [ENV.fetch("AGENT_GUARD")]
  else
    [RbConfig.ruby, "--disable-gems", ROOT.join("bin/agent-guard").to_s]
  end.freeze
  BLOCKED_MESSAGE = "BLOCKED: create worktrees with EnterWorktree (name), which runs the WorktreeCreate hook and moves this session into the new worktree.\n"
  HOME = "/Users/agent"

  def test_direct_worktree_creation_uses_enter_worktree
    result = run_guard("git worktree add ../feature")

    assert_equal 2, result[:status]
    assert_equal "", result[:stdout]
    assert_equal BLOCKED_MESSAGE, result[:stderr]
  end

  def test_worktree_creation_with_an_explicit_repository_uses_enter_worktree
    result = run_guard("git -C ~/Code/dotfiles worktree add ../dotfiles-feature")

    assert_equal 2, result[:status]
    assert_equal "", result[:stdout]
    assert_equal BLOCKED_MESSAGE, result[:stderr]
  end

  def test_other_commands_with_an_explicit_repository_continue
    result = run_guard("git -C ~/Code/backend/backend status --short")

    assert_equal 0, result[:status]
    assert_equal "", result[:stdout]
    assert_equal "", result[:stderr]
  end

  def test_entering_a_worktree_from_another_directory_uses_enter_worktree
    target = "#{HOME}/Code/worktrees/backend/feature"
    result = run_guard("cd ~/Code/worktrees/backend/feature && bundle exec rake")

    assert_equal 2, result[:status]
    assert_equal "", result[:stdout]
    assert_equal "BLOCKED: this session runs in /tmp/repository. Call EnterWorktree with path #{target} so every command starts there, then rerun without the cd.\n", result[:stderr]
  end

  def test_commands_inside_the_target_worktree_continue
    result = run_guard(
      "cd $HOME/Code/worktrees/backend/feature && bundle exec rake",
      cwd: "#{HOME}/Code/worktrees/backend/feature/app"
    )

    assert_equal 0, result[:status]
    assert_equal "", result[:stdout]
    assert_equal "", result[:stderr]
  end

  private

  def run_guard(command, cwd: "/tmp/repository")
    stdout, stderr, status = Open3.capture3(
      {"HOME" => HOME, "RUBYOPT" => nil, "RUBYLIB" => nil},
      *GUARD,
      stdin_data: JSON.generate(tool_input: {command: command}, cwd: cwd)
    )

    {stdout: stdout, stderr: stderr, status: status.exitstatus}
  end
end
