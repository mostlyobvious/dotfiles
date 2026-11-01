require "agent_hooks/worktree/command_runner"
require "agent_hooks/worktree/creator"
require "agent_hooks/worktree/devenv"
require "agent_hooks/worktree/lease_decider"
require "agent_hooks/worktree/state_file"

module AgentHooks
  module Worktree
    STALE_AFTER = 7 * 24 * 60 * 60
    def self.run(event, env:, out:, err:, now:)
      case event.fetch("hook_event_name")
      when "WorktreeCreate"
        Creator.call(event, env, out, err)
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

    private_class_method :observe, :heartbeat, :finish, :reconcile
    private_constant :STALE_AFTER
  end
end
