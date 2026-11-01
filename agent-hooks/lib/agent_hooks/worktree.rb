require "fileutils"
require "agent_hooks/worktree/command_runner"
require "agent_hooks/worktree/devenv"
require "agent_hooks/worktree/lease_decider"
require "agent_hooks/worktree/state_file"

module AgentHooks
  module Worktree
    STALE_AFTER = 7 * 24 * 60 * 60
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

      StateFile.update(env) do |state|
        LeaseDecider.apply(state, type: :record_activity, session: session, at: timestamp)
        LeaseDecider.apply(state, type: :expire_leases, before: timestamp - STALE_AFTER)

        root = Devenv.started_root(event)
        if root&.start_with?("#{env.fetch("HOME")}/Code/worktrees/")
          LeaseDecider.apply(state, type: :record_devenv_started, root: root, session: session, at: timestamp)
        end

        reconcile(state, err)
      end
    end

    def self.heartbeat(event, env, err, timestamp)
      session = event["session_id"]
      return 0 unless session

      StateFile.update(env) do |state|
        LeaseDecider.apply(state, type: :record_activity, session: session, at: timestamp)
        LeaseDecider.apply(state, type: :expire_leases, before: timestamp - STALE_AFTER)
        reconcile(state, err)
      end
    end

    def self.finish(event, env, err)
      session = event["session_id"]
      return 0 unless session

      StateFile.update(env) do |state|
        LeaseDecider.apply(state, type: :end_session, session: session)
        reconcile(state, err)
      end
    end

    def self.reconcile(state, err)
      LeaseDecider.unowned_roots(state).each do |root|
        LeaseDecider.apply(state, type: :remove_root, root: root) if Devenv.stop(root, err)
      end
    end

    def self.capture(*command)
      result = CommandRunner.run(command)
      result.output if result.success
    end

    def self.execute(command, err, chdir: nil)
      result = CommandRunner.run(command, chdir: chdir)
      err.write(result.output)
      result.success
    end

    def self.fail_with(message, err)
      err.puts(message)
      1
    end

    private_class_method :create, :observe, :heartbeat, :finish, :reconcile,
      :capture, :execute, :fail_with
    private_constant :STALE_AFTER
  end
end
