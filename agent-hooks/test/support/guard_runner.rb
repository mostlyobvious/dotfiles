require "json"
require "open3"
require "pathname"
require "rbconfig"

module GuardRunner
  HOME = "/Users/agent"
  ROOT = Pathname(__dir__).join("../..").expand_path
  GUARD = if ENV["AGENT_GUARD"]
    [ENV.fetch("AGENT_GUARD")]
  else
    [RbConfig.ruby, "--disable-gems", ROOT.join("bin/agent-guard").to_s]
  end.freeze

  def run_guard(command = nil, cwd: "/tmp/repository", **extra)
    tool_input = extra.delete(:tool_input) || {command: command}
    event = {hook_event_name: "PreToolUse", tool_input: tool_input, cwd: cwd}.merge(extra)

    stdout, stderr, status = Open3.capture3(
      {"HOME" => HOME, "RUBYOPT" => nil, "RUBYLIB" => nil},
      *GUARD,
      stdin_data: JSON.generate(event)
    )

    {stdout: stdout, stderr: stderr, status: status.exitstatus}
  end
end
