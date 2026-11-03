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
      "BLOCKED: commit messages, MR/PR descriptions, artifacts, and Linear prose require reading and applying change-writing/SKILL.md first. For an MR/PR description, apply it after the latest description edit.\n"
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

    def artifact(
      tool_name: "Artifact",
      change_writing_applied: false,
      transcript_path: nil,
      **tool_input
    )
      guarded_tool(
        tool_name,
        tool_input,
        change_writing_applied: change_writing_applied,
        transcript_path: transcript_path
      )
    end

    def guarded_tool(
      tool_name,
      tool_input,
      change_writing_applied: false,
      transcript_path: nil
    )
      status, message, =
        Guard.run(
          {
            "hook_event_name" => "PreToolUse",
            "tool_name" => tool_name,
            "tool_input" => tool_input.transform_keys(&:to_s),
            "cwd" => "/tmp",
            "change_writing_applied" => change_writing_applied,
            "transcript_path" => transcript_path
          },
          "/Users/agent"
        )
      [status, message]
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

    def conversation(directory, *messages)
      lines =
        messages.map do |message|
          case message
          in String
            JSON.generate(
              { type: "user", message: { role: "user", content: message } }
            )
          in :tool_result
            JSON.generate(
              {
                type: "user",
                message: {
                  role: "user",
                  content: [{ type: "tool_result", content: "ok" }]
                }
              }
            )
          in [:meta, text]
            JSON.generate(
              {
                type: "user",
                isMeta: true,
                message: {
                  role: "user",
                  content: text
                }
              }
            )
          in [:assistant, text]
            JSON.generate(
              {
                type: "assistant",
                message: {
                  role: "assistant",
                  content: text
                }
              }
            )
          in :unreadable
            "{"
          end
        end
      path = "#{directory}/conversation.jsonl"
      File.write(path, lines.join("\n"))
      path
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

    def call(command, cwd: "/tmp/repository", home: "/Users/agent", **event)
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

    def change_writing_transcript(directory, *events)
      records =
        events.map do |event|
          if event == :applied
            { message: { content: "# Change Writing" } }
          else
            name, path = event
            {
              message: {
                content: [
                  { type: "tool_use", name: name, input: { file_path: path } }
                ]
              }
            }
          end
        end
      path = "#{directory}/transcript.jsonl"
      File.write(
        path,
        records.map { |record| JSON.generate(record) }.join("\n")
      )
      path
    end
  end
end
