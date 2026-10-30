require "fileutils"
require "json"

module AgentHooks
  module Worktree
    STALE_AFTER = 7 * 24 * 60 * 60
    DEVENV_UP = /(?:\A|[&|;(]\s*)devenv(?:\s+[^&|;\s]+)*\s+up(?:\s|\z)/

    def self.run(event, env: ENV, out: $stdout, err: $stderr)
      case event["hook_event_name"]
      when "WorktreeCreate"
        create(event, env, out, err)
      when "PostToolUse"
        observe(event, env, err)
      when "SessionEnd"
        finish(event, env, err)
      else
        0
      end
    end

    def self.create(event, env, out, err)
      home = env.fetch("HOME")
      name = event.fetch("name")
      cwd = event.fetch("cwd")
      common_dir = capture("git", "-C", cwd, "rev-parse", "--path-format=absolute", "--git-common-dir")
      return fail_with("Could not find the repository for #{cwd}", err) unless common_dir

      main_root = File.dirname(common_dir.strip)
      return fail_with("dotfiles is edited in its main checkout, never in a linked worktree.", err) if main_root == "#{home}/Code/dotfiles"

      slug = name.gsub(/[^[:alnum:]._-]/, "-")
      destination = "#{home}/Code/worktrees/#{File.basename(main_root)}/#{slug}"
      return fail_with("Worktree path already exists: #{destination}", err) if File.exist?(destination)

      origin_head = capture("git", "-C", main_root, "symbolic-ref", "--quiet", "refs/remotes/origin/HEAD")
      unless origin_head
        system("git", "-C", main_root, "remote", "set-head", "origin", "--auto", out: err, err: err)
        origin_head = capture("git", "-C", main_root, "symbolic-ref", "--quiet", "refs/remotes/origin/HEAD")
      end
      base_ref = origin_head ? origin_head.strip.sub(%r{\Arefs/remotes/}, "") : "HEAD"

      FileUtils.mkdir_p(File.dirname(destination))
      branch_exists = system("git", "-C", main_root, "show-ref", "--verify", "--quiet", "refs/heads/#{name}", out: File::NULL, err: File::NULL)
      command = ["git", "-C", main_root, "worktree", "add"]
      command += ["-b", name, destination, base_ref] unless branch_exists
      command += [destination, name] if branch_exists
      return 1 unless system(*command, out: err, err: err)

      if File.file?("#{destination}/devenv.nix")
        return 1 unless system("devenv", "allow", chdir: destination, out: err, err: err)
      end
      out.puts(destination)
      0
    end

    def self.observe(event, env, err)
      session = event["session_id"]
      return 0 unless session

      with_state(env) do |state|
        prune(state, env, err)
        state["seen"][session] = now(env)

        command = event.fetch("tool_input").fetch("command")
        next unless DEVENV_UP.match?(command)

        root = capture("git", "-C", event.fetch("cwd"), "rev-parse", "--show-toplevel")
        next unless root

        root = root.strip
        next unless root.start_with?("#{env.fetch("HOME")}/Code/worktrees/")

        state["sessions"][session] ||= []
        state["sessions"][session] << root unless state["sessions"][session].include?(root)
        state["roots"][root] ||= []
        state["roots"][root] << session unless state["roots"][root].include?(session)
      end
      0
    end

    def self.finish(event, env, err)
      session = event["session_id"]
      return 0 unless session

      with_state(env) { |state| release(state, session, err) }
      0
    end

    def self.prune(state, env, err)
      cutoff = now(env) - STALE_AFTER
      state["seen"].select { |_session, seen| seen < cutoff }.each_key do |session|
        release(state, session, err)
      end
    end

    def self.release(state, session, err)
      roots = state["sessions"].delete(session) || []
      state["seen"].delete(session)
      roots.each do |root|
        sessions = state["roots"].fetch(root, []) - [session]
        if sessions.empty?
          state["roots"].delete(root)
          stop(root, err)
        else
          state["roots"][root] = sessions
        end
      end
    end

    def self.stop(root, err)
      return unless File.directory?(root)
      return if system("devenv", "down", chdir: root, out: File::NULL, err: File::NULL)

      err.puts("Failed to stop devenv processes for #{root}")
    end

    def self.with_state(env)
      directory = "#{env["XDG_STATE_HOME"] || "#{env.fetch("HOME")}/.local/state"}/agent-worktree"
      FileUtils.mkdir_p(directory)
      File.open("#{directory}/lock", File::RDWR | File::CREAT, 0o600) do |lock|
        lock.flock(File::LOCK_EX)
        path = "#{directory}/state.json"
        state = File.file?(path) ? JSON.parse(File.read(path)) : {"sessions" => {}, "roots" => {}, "seen" => {}}
        yield state
        File.write("#{path}.next", JSON.generate(state))
        File.rename("#{path}.next", path)
      end
    end

    def self.capture(*command)
      output = IO.popen(command, err: File::NULL, &:read)
      output if $?.success?
    end

    def self.now(env)
      env["AGENT_WORKTREE_NOW"] ? Integer(env["AGENT_WORKTREE_NOW"], 10) : Time.now.to_i
    end

    def self.fail_with(message, err)
      err.puts(message)
      1
    end
  end
end
