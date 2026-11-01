module AgentHooks
  module Guard
    Decision = Struct.new(:status, :message, keyword_init: true)
    Context =
      Struct.new(:event, :home, :command, :cwd, :program, keyword_init: true)

    module Policies
      BLOCKED_MESSAGE =
        "BLOCKED: create worktrees through the session host so every command starts in the worktree.\n"
      CHANGE_WRITING_MESSAGE =
        "BLOCKED: commit messages and MR/PR descriptions require reading and applying change-writing/SKILL.md first.\n"
      ATTRIBUTION_MESSAGE =
        "BLOCKED: commit messages must not include Anthropic or Claude co-author attribution.\n"
      UNSUPPORTED_MESSAGE =
        "BLOCKED: agent-guard cannot inspect this shell syntax safely. Put the command in a reviewed script and run that script.\n"
      SHELL_EDIT_REASON =
        "edits files through an in-place shell command. Use Edit for existing files or Write for new files and complete rewrites."
      COAUTHOR_ATTRIBUTION =
        /co-authored-by:.*(?:anthropic|claude)|(?:(?:anthropic|claude).*)co-authored-by:/i

      def self.evaluate(context)
        decision = UnsupportedShell.call(context)
        decision ||= Git.call(context)
        decision ||= ShellEdit.call(context)
        decision ||= ChangeWriting.call(context)
        decision ||= Attribution.call(context)
        decision ||= Worktree.call(context)
        decision || Decision.new(status: 0, message: "")
      end

      def self.blocked(context, reason)
        Decision.new(
          status: 2,
          message:
            "BLOCKED: '#{context.command}' #{reason} The user has prevented you from doing this.\n"
        )
      end

      module UnsupportedShell
        def self.call(context)
          return if context.program.supported

          Decision.new(status: 2, message: UNSUPPORTED_MESSAGE)
        end
      end

      module Git
        def self.call(context)
          context.program.commands.each do |command|
            if command.git_subcommand == "worktree" &&
                 command.git_arguments.first == "add"
              dotfiles = "#{context.home}/Code/dotfiles"
              if context.cwd == dotfiles ||
                   context.cwd.start_with?("#{dotfiles}/") ||
                   command.words.any? { |word|
                     %r{(?:Code|worktrees)/dotfiles}.match?(word)
                   }
                return(
                  Policies.blocked(
                    context,
                    "adds a worktree to dotfiles, which is edited in its main checkout."
                  )
                )
              end
            end

            case command.argv
            in ["glab", "mr", "create" | "update", *arguments]
              if arguments.any? { |argument|
                   argument == "-d" || argument == "--description" ||
                     argument.start_with?("--description=")
                 }
                return(
                  Policies.blocked(
                    context,
                    "passes an MR description inline. Use mr-describe <iid> <file> to update one, or a shell script that reads the file to create one."
                  )
                )
              end
            else
            end

            if command.git_subcommand == "push"
              if command.git_arguments.any? { |argument|
                   argument == "--force" || argument.match?(/\A-[^-]*f/)
                 }
                return Policies.blocked(context, "is a force push.")
              end
              if command.git_arguments.any? { |argument|
                   %r{(?:\A|[:/])(?:refs/heads/)?(?:master|main)\z}.match?(
                     argument
                   )
                 }
                return Policies.blocked(context, "pushes a protected branch.")
              end
            end

            label =
              case command.git_subcommand
              when "reset"
                "git reset --hard" if command.git_arguments.include?("--hard")
              when "clean"
                if command.git_arguments.any? { |argument|
                     argument.match?(/\A-[^-]*f/)
                   }
                  if command.git_arguments.include?("-fd")
                    "git clean -fd"
                  else
                    "git clean -f"
                  end
                end
              when "checkout"
                "git checkout \\." if command.git_arguments.include?(".")
              when "restore"
                "git restore \\." if command.git_arguments.include?(".")
              end
            label ||= "reset --hard" if command
              .words
              .each_cons(2)
              .any? { |left, right| left == "reset" && right == "--hard" }
            if label
              return(
                Decision.new(
                  status: 2,
                  message:
                    "BLOCKED: '#{context.command}' matches dangerous pattern '#{label}'. The user has prevented you from doing this.\n"
                )
              )
            end
          end
          nil
        end
      end

      module ShellEdit
        def self.call(context)
          edit =
            context.program.commands.any? do |command|
              case command.executable
              when "sed"
                command.arguments.any? do |argument|
                  argument == "--in-place" ||
                    argument.start_with?("--in-place=") ||
                    argument.start_with?("-i")
                end
              when "perl"
                command.arguments.any? do |argument|
                  argument.match?(/\A-[0-9A-Za-z]*i[0-9A-Za-z]*\z/)
                end
              end
            end
          if edit
            Decision.new(
              status: 2,
              message: "BLOCKED: '#{context.command}' #{SHELL_EDIT_REASON}\n"
            )
          end
        end
      end

      module ChangeWriting
        def self.call(context)
          merge_request =
            lambda do |command|
              case command.argv
              in ["glab", "mr", "create" | "edit" | "update", *]
                true
              in ["gh", "pr", "create" | "edit", *]
                true
              else
                false
              end
            end

          writes_prose =
            context.program.commands.any? do |command|
              commit =
                command.git_subcommand == "commit" &&
                  !command.git_arguments.any? do |argument|
                    argument == "--no-edit" || argument == "--fixup"
                  end
              script = command.executable
              publishes =
                if script&.end_with?(".sh")
                  path =
                    if script.start_with?("/")
                      script
                    elsif script.start_with?("~/")
                      script.sub("~/", "#{context.home}/")
                    else
                      "#{context.cwd}/#{script}"
                    end
                  File.file?(path) &&
                    ShellCommand
                      .parse(File.read(path))
                      .commands
                      .any?(&merge_request)
                end
              merge_request.call(command) || commit || publishes
            end
          return unless writes_prose
          return if context.event["change_writing_applied"]

          transcript = context.event["transcript_path"]
          if transcript && File.file?(transcript) &&
               File.read(transcript).include?("# Change Writing")
            return
          end

          Decision.new(status: 2, message: CHANGE_WRITING_MESSAGE)
        end
      end

      module Attribution
        def self.call(context)
          commit =
            context.program.commands.any? do |command|
              command.git_subcommand == "commit"
            end
          if commit && COAUTHOR_ATTRIBUTION.match?(context.command)
            Decision.new(status: 2, message: ATTRIBUTION_MESSAGE)
          end
        end
      end

      module Worktree
        def self.call(context)
          if context.program.commands.any? { |command|
               command.git_subcommand == "worktree" &&
                 command.git_arguments.first == "add"
             }
            return Decision.new(status: 2, message: BLOCKED_MESSAGE)
          end

          context.program.commands.each do |command|
            next unless command.executable == "cd"

            path = command.arguments.first
            next unless path
            normalized =
              path.sub("$HOME", context.home).sub("~/", "#{context.home}/")
            root = "#{context.home}/Code/worktrees/"
            next unless normalized.start_with?(root)

            repository, worktree =
              normalized[root.length, normalized.length].split("/")
            next unless worktree

            target = "#{root}#{repository}/#{worktree}"
            if context.cwd == target || context.cwd.start_with?("#{target}/")
              next
            end

            return(
              Decision.new(
                status: 2,
                message:
                  "BLOCKED: this session runs in #{context.cwd}. Start or move the session to #{target} so every command starts there, then rerun without the cd.\n"
              )
            )
          end
          nil
        end
      end

      private_constant :BLOCKED_MESSAGE,
                       :CHANGE_WRITING_MESSAGE,
                       :ATTRIBUTION_MESSAGE,
                       :UNSUPPORTED_MESSAGE,
                       :SHELL_EDIT_REASON,
                       :COAUTHOR_ATTRIBUTION,
                       :UnsupportedShell,
                       :Git,
                       :ShellEdit,
                       :ChangeWriting,
                       :Attribution,
                       :Worktree
    end

    private_constant :Decision, :Context, :Policies
  end
end
