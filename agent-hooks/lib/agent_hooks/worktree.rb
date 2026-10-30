require "fileutils"
require "json"

module AgentHooks
  module Worktree
    STALE_AFTER = 7 * 24 * 60 * 60
    DEVENV_UP = /(?:\A|[&|;(]\s*)devenv(?:\s+[^&|;\s]+)*\s+up(?:\s|\z)/
    NO_PROCESS_MANAGER = "No process manager is running"

    def self.run(event, env:, out:, err:, now:)
      case event.fetch("hook_event_name")
      when "WorktreeCreate"
        create(event, env, out, err)
      when "PostToolUse"
        observe(event, env, err, now)
      when "Heartbeat", "SessionStart", "UserPromptSubmit"
        heartbeat(event, env, err, now)
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

      main_root = File.dirname(common_dir)
      return fail_with("dotfiles is edited in its main checkout, never in a linked worktree.", err) if main_root == "#{home}/Code/dotfiles"

      slug = name.gsub(/[^[:alnum:]._-]/, "-")
      destination = "#{home}/Code/worktrees/#{File.basename(main_root)}/#{slug}"
      return fail_with("Worktree path already exists: #{destination}", err) if File.exist?(destination)

      origin_head = capture("git", "-C", main_root, "symbolic-ref", "--quiet", "refs/remotes/origin/HEAD")
      unless origin_head
        execute(["git", "-C", main_root, "remote", "set-head", "origin", "--auto"], err)
        origin_head = capture("git", "-C", main_root, "symbolic-ref", "--quiet", "refs/remotes/origin/HEAD")
      end
      base_ref = origin_head ? origin_head.chomp.sub(%r{\Arefs/remotes/}, "") : "HEAD"

      FileUtils.mkdir_p(File.dirname(destination))
      branch_exists = !capture("git", "-C", main_root, "show-ref", "--verify", "--quiet", "refs/heads/#{name}").nil?
      command = ["git", "-C", main_root, "worktree", "add"]
      command += ["-b", name, destination, base_ref] unless branch_exists
      command += [destination, name] if branch_exists
      return 1 unless execute(command, err)

      if File.file?("#{destination}/devenv.nix") && !execute(["devenv", "allow"], err, chdir: destination)
        err.puts("devenv allow failed for #{destination}; run it there before using devenv.")
      end
      out.puts(destination)
      0
    end

    def self.observe(event, env, err, timestamp)
      session = event["session_id"]
      return 0 unless session

      with_state(env) do |state|
        touch(state, session, timestamp)
        expire(state, timestamp)

        command = event.fetch("tool_input")["command"]
        if DEVENV_UP.match?(command)
          root = capture("git", "-C", event.fetch("cwd"), "rev-parse", "--show-toplevel")
          claim(state, root.chomp, session, timestamp, env) if root
        end

        reconcile(state, err)
      end
    end

    def self.heartbeat(event, env, err, timestamp)
      session = event["session_id"]
      return 0 unless session

      with_state(env) do |state|
        touch(state, session, timestamp)
        expire(state, timestamp)
        reconcile(state, err)
      end
    end

    def self.finish(event, env, err)
      session = event["session_id"]
      return 0 unless session

      with_state(env) do |state|
        state.fetch("roots").each_value { |root| root.fetch("owners").delete(session) }
        reconcile(state, err)
      end
    end

    def self.claim(state, root, session, timestamp, env)
      return unless root.start_with?("#{env.fetch("HOME")}/Code/worktrees/")

      ownership = state.fetch("roots")[root] ||= {"owners" => {}}
      ownership.fetch("owners")[session] = timestamp
    end

    def self.touch(state, session, timestamp)
      state.fetch("roots").each_value do |root|
        owners = root.fetch("owners")
        owners[session] = timestamp if owners.key?(session)
      end
    end

    def self.expire(state, timestamp)
      cutoff = timestamp - STALE_AFTER
      state.fetch("roots").each_value do |root|
        root.fetch("owners").delete_if { |_session, seen| seen < cutoff }
      end
    end

    def self.reconcile(state, err)
      state.fetch("roots").delete_if do |root, ownership|
        ownership.fetch("owners").empty? && stop(root, err)
      end
    end

    def self.stop(root, err)
      return true unless File.directory?(root)

      output = IO.popen(["devenv", "down"], chdir: root, err: [:child, :out], &:read)
      return true if $?.success? || output.include?(NO_PROCESS_MANAGER)

      err.puts("Failed to stop devenv processes for #{root}: #{output}")
    end

    def self.with_state(env)
      state_home = env["XDG_STATE_HOME"]
      state_home ||= File.join(env.fetch("HOME"), ".local", "state")
      directory = File.join(state_home, "agent-worktree")
      FileUtils.mkdir_p(directory)
      lock = File.new("#{directory}/lock", File::CREAT, 0o600)
      lock.flock(File::LOCK_EX)
      path = "#{directory}/state.json"
      state = File.file?(path) ? normalize(JSON.parse(File.read(path))) : {"roots" => {}}
      yield state
      File.write("#{path}.next", JSON.generate(state))
      File.rename("#{path}.next", path)
    ensure
      lock&.close
    end

    def self.normalize(state)
      return state unless state.key?("sessions")

      seen = state.fetch("seen")
      roots = state.fetch("roots").to_h do |root, sessions|
        owners = sessions.to_h { |session| [session, seen.fetch(session)] }
        [root, {"owners" => owners}]
      end
      {"roots" => roots}
    end

    def self.capture(*command)
      output = IO.popen(command, err: File::NULL, &:read)
      output if $?.success?
    end

    def self.execute(command, err, chdir: nil)
      output = if chdir
        IO.popen(command, chdir: chdir, err: [:child, :out], &:read)
      else
        IO.popen(command, err: [:child, :out], &:read)
      end
      err.write(output)
      $?.success?
    end

    def self.fail_with(message, err)
      err.puts(message)
      1
    end

    private_class_method :create, :observe, :heartbeat, :finish, :claim, :touch, :expire, :reconcile,
      :stop, :with_state, :normalize, :capture, :execute, :fail_with
    private_constant :STALE_AFTER, :DEVENV_UP, :NO_PROCESS_MANAGER
  end
end
