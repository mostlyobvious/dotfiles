require "fileutils"
require "json"
require "minitest/autorun"
require "mutant/minitest/coverage"
require "tmpdir"
require_relative "../../lib/agent_hooks/guard"
require_relative "repositories"

module AgentHooks
  module GuardHelpers
    include Repositories

    ATTRIBUTION_MESSAGE =
      "BLOCKED: commit messages must not include Anthropic or Claude co-author attribution.\n"
    CHANGE_WRITING_MESSAGE =
      "BLOCKED: commit messages, MR/PR descriptions, artifacts, and Linear prose require the change-writing skill first: invoke it with the Skill tool (pi: read its SKILL.md). For an MR/PR description, invoke it again after the latest description edit.\n"
    MR_REMINDER =
      "If the pushed branch has an open MR, compare its description with the new diff and propose an update when they disagree (merge-request skill, step 8)."
    REVIEW_REMINDER =
      "Run the change-writing Review Pass on mr-description.md before presenting it for approval (merge-request skill, step 6)."
    WORKTREE_MESSAGE =
      "BLOCKED: use the session host's worktree tool (Claude Code: EnterWorktree) instead of git worktree add so every command starts in the worktree. For another repository's worktree, run git -C <repository> worktree add ~/Code/worktrees/<repository name>/<name>.\n"
    COMMIT_FILE_MESSAGE =
      "BLOCKED: write commit messages to a file and pass it with git commit -F.\n"
    COMMIT_FORMAT_MESSAGE =
      "BLOCKED: the commit message must have a capitalized subject of at most 50 characters without a trailing period, a blank line before its body, and body lines of at most 72 characters.\n"
    MR_SCRIPT_MESSAGE =
      "BLOCKED: open GitLab merge requests through a shell script that reads the approved description from a file.\n"
    MR_SQUASH_MESSAGE =
      "BLOCKED: GitLab merge request creation requires --squash-before-merge=false.\n"
    DEVENV_DETACH_MESSAGE =
      "BLOCKED: start worktree services with devenv up -d.\n"
    DEVENV_ROOT_MESSAGE = "BLOCKED: run devenv up -d from the worktree root.\n"
    FORCE_PUSH_REASON =
      "is a force push. Use --force-with-lease after an amend or rebase on a feature branch."

    def artifact(
      tool_name: "Artifact",
      home: "/Users/agent",
      session: nil,
      **tool_input
    )
      guarded_tool(tool_name, tool_input, home: home, session: session)
    end

    def guarded_tool(tool_name, tool_input, home: "/Users/agent", session: nil)
      status, message, =
        Guard.run(
          {
            "hook_event_name" => "PreToolUse",
            "session_id" => session,
            "tool_name" => tool_name,
            "tool_input" => tool_input.transform_keys(&:to_s),
            "cwd" => "/tmp"
          },
          home
        )
      [status, message]
    end

    def with_session
      Dir.mktmpdir { |home| yield home, "session" }
    end

    def prompt(home, session, text)
      Guard.run(
        {
          "hook_event_name" => "UserPromptSubmit",
          "session_id" => session,
          "prompt" => text
        },
        home
      )
    end

    def observe(home, session, tool_name, **tool_input)
      Guard.run(
        {
          "hook_event_name" => "PostToolUse",
          "session_id" => session,
          "tool_name" => tool_name,
          "tool_input" => tool_input.transform_keys(&:to_s)
        },
        home
      )
    end

    def change_writing(home, session)
      observe(home, session, "Skill", skill: "change-writing")
    end

    def finish(home, session)
      Guard.run(
        { "hook_event_name" => "SessionEnd", "session_id" => session },
        home
      )
    end

    def facts_file(home, session)
      "#{home}/.local/state/agent-guard/#{session}.json"
    end

    def with_repository(name, branch:)
      Dir.mktmpdir do |home|
        root = "#{home}/Code/#{name}"
        FileUtils.mkdir_p(root)
        system(
          "git",
          "init",
          "--quiet",
          "--initial-branch=#{branch}",
          root,
          out: File::NULL,
          err: File::NULL
        ) or raise "git init failed"
        yield root, home
      end
    end

    def with_worktree
      Dir.mktmpdir do |home|
        root = "#{home}/Code/worktrees/backend/feature"
        FileUtils.mkdir_p(root)
        system(
          "git",
          "init",
          "--quiet",
          "--initial-branch=feature",
          root,
          out: File::NULL,
          err: File::NULL
        ) or raise "git init failed"
        yield root, home
      end
    end

    def enter_worktree(cwd, target)
      [
        2,
        "BLOCKED: this session runs in #{cwd}. Use the session host's worktree tool (Claude Code: EnterWorktree) with path #{target}, then rerun the command without cd.\n"
      ]
    end

    def with_commit_message(message)
      Dir.mktmpdir do |directory|
        path = "#{directory}/message"
        File.write(path, message)
        yield path
      end
    end

    def blocked
      [2, WORKTREE_MESSAGE]
    end

    def cannot_inspect(reason)
      "BLOCKED: agent-guard cannot inspect this command: #{reason}. Fix the syntax, or put it in a reviewed .sh file and run that file.\n"
    end

    def policy_blocked(command, reason)
      [2, "BLOCKED: '#{command}' #{reason}\n"]
    end

    def needs_go(command, reason)
      [
        2,
        "BLOCKED: '#{command}' #{reason} Ask the user for exact 'go', then retry unchanged.\n"
      ]
    end

    def reminder(message)
      {
        "hookSpecificOutput" => {
          "hookEventName" => "PostToolUse",
          "additionalContext" => message
        }
      }
    end

    def shell_edit_blocked(command)
      [
        2,
        "BLOCKED: '#{command}' edits files through an in-place shell command. Use Edit for existing files or Write for new files and complete rewrites.\n"
      ]
    end

    def call(
      command,
      cwd: "/tmp/repository",
      home: "/Users/agent",
      change_writing: false,
      **event
    )
      if change_writing
        return(
          with_session do |session_home, session|
            change_writing(session_home, session)
            call(
              command,
              cwd: cwd,
              home: session_home,
              session_id: session,
              **event
            )
          end
        )
      end

      status, message, =
        Guard.run(
          {
            "hook_event_name" => "PreToolUse",
            "tool_input" => {
              "command" => command
            },
            "cwd" => cwd
          }.merge(event.transform_keys(&:to_s)),
          home
        )
      [status, message]
    end
  end
end
