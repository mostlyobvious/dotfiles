module AgentHooks
  module Guard
    Decision = Struct.new(:status, :message, keyword_init: true)
    Context =
      Struct.new(:event, :home, :command, :cwd, :program, keyword_init: true)

    module Policies
      BLOCKED_MESSAGE =
        "BLOCKED: use the session host's worktree tool (Claude Code: EnterWorktree) instead of git worktree add so every command starts in the worktree.\n"
      CHANGE_WRITING_MESSAGE =
        "BLOCKED: commit messages, MR/PR descriptions, artifacts, and Linear prose require reading and applying change-writing/SKILL.md first. For an MR/PR description, apply it after the latest description edit.\n"
      LINEAR_WRITE = /\Amcp__.*linear__(?:save_|submit_diff_review)/i
      LINEAR_PROSE_KEYS = %w[body content description summary title].freeze
      ATTRIBUTION_MESSAGE =
        "BLOCKED: commit messages must not include Anthropic or Claude co-author attribution.\n"
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
      DEVENV_ROOT_MESSAGE =
        "BLOCKED: run devenv up -d from the worktree root.\n"
      UNSUPPORTED_MESSAGE =
        "BLOCKED: agent-guard cannot inspect this shell syntax safely. Split it into static commands, or put it in a reviewed .sh file and run that file.\n"
      SHELL_EDIT_REASON =
        "edits files through an in-place shell command. Use Edit for existing files or Write for new files and complete rewrites."
      COAUTHOR_ATTRIBUTION =
        /co-authored-by:.*(?:anthropic|claude)|(?:(?:anthropic|claude).*)co-authored-by:/i

      def self.evaluate(context)
        decision = UnsupportedShell.call(context)
        decision ||= Git.call(context)
        decision ||= ShellEdit.call(context)
        decision ||= Devenv.call(context)
        decision ||= ChangeWriting.call(context)
        decision ||= MergeRequest.call(context)
        decision ||= Commit.call(context)
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

      def self.unless_go(context, reason)
        return if go?(context.event)

        Decision.new(
          status: 2,
          message:
            "BLOCKED: '#{context.command}' #{reason} Ask the user for exact 'go', then retry unchanged.\n"
        )
      end

      def self.go?(event)
        return event["last_user_text"] == "go" if event.key?("last_user_text")

        path = event["transcript_path"].to_s
        return false unless File.file?(path)

        File
          .readlines(path, chomp: true)
          .reverse_each do |line|
            record = JSON.parse(line)
            next unless record["type"] == "user" && !record["isMeta"]

            content = record.dig("message", "content")
            return content == "go" if content.is_a?(String)
          rescue JSON::ParserError
            next
          end
        false
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

            if command.git_subcommand == "commit" &&
                 command.git_arguments.include?("--no-verify")
              return(
                Policies.blocked(
                  context,
                  "skips commit hooks with --no-verify."
                )
              )
            end

            if command.git_subcommand == "push"
              if command.git_arguments.any? { |argument|
                   argument == "--force" || argument.match?(/\A-[^-]*f/)
                 }
                return Policies.blocked(context, "is a force push.")
              end
              target =
                command
                  .git_arguments
                  .filter_map { |argument| protected_branch(argument) }
                  .first
              repository = GitRepository.current(context.cwd)
              ref =
                command
                  .git_arguments
                  .reject { |argument| argument.start_with?("-") }
                  .at(1)
              if (target && !chattermill_main?(repository, target)) ||
                   (
                     !ref && protected_branch(repository.branch) &&
                       !chattermill_main?(repository, repository.branch)
                   )
                decision =
                  Policies.unless_go(context, "pushes a protected branch.")
                return decision if decision
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
              decision =
                Policies.unless_go(
                  context,
                  "matches dangerous pattern '#{label}'."
                )
              return decision if decision
            end
          end
          nil
        end

        def self.protected_branch(argument)
          match =
            %r{(?:\A|[:/])(?:refs/heads/)?(?<branch>master|main)\z}.match(
              argument
            )
          match && match["branch"]
        end

        def self.chattermill_main?(repository, branch)
          File.basename(repository.root) == "chattermill" && branch == "main"
        end

        private_class_method :protected_branch, :chattermill_main?
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

      module Devenv
        def self.call(context)
          worktrees = "#{context.home}/Code/worktrees/"
          return unless context.cwd.start_with?(worktrees)

          context.program.commands.each do |command|
            next unless command.executable == "devenv"
            next unless command.arguments.first == "up"

            unless command.arguments.include?("-d")
              return Decision.new(status: 2, message: DEVENV_DETACH_MESSAGE)
            end
            unless GitRepository.current(context.cwd).root ==
                     File.realpath(context.cwd)
              return Decision.new(status: 2, message: DEVENV_ROOT_MESSAGE)
            end
          end
          nil
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
              in ["mr-describe", _, _, *]
                true
              else
                false
              end
            end

          artifact =
            context.event["tool_name"] == "Artifact" &&
              context.event.fetch("tool_input").fetch("action", "publish") ==
                "publish"
          writes_prose =
            artifact || linear_publication?(context.event) ||
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
          if transcript && File.file?(transcript)
            lines = File.readlines(transcript)
            applied = lines.rindex { |line| line.include?("# Change Writing") }
            command =
              context.program.commands.find do |candidate|
                candidate.executable == "mr-describe"
              end
            file = (command ? command.arguments.fetch(1) : "mr-description.md")
            edited =
              lines.rindex do |line|
                line.match?(/"name":"(?:Edit|Write)"/) &&
                  line.include?(%Q{"file_path":#{JSON.generate(file)}})
              end
            return if applied && (!edited || applied > edited)
          end

          Decision.new(status: 2, message: CHANGE_WRITING_MESSAGE)
        end

        def self.linear_publication?(event)
          LINEAR_WRITE.match?(event.fetch("tool_name", nil)) &&
            event
              .fetch("tool_input")
              .keys
              .any? { |key| LINEAR_PROSE_KEYS.include?(key) }
        end

        private_class_method :linear_publication?
      end

      module MergeRequest
        def self.call(context)
          if context.program.commands.any? { |command| create?(command) }
            return Decision.new(status: 2, message: MR_SCRIPT_MESSAGE)
          end

          context.program.commands.each do |command|
            script = command.executable
            next unless script&.end_with?(".sh")

            path = File.expand_path(script, context.cwd)
            next unless File.file?(path)

            creates =
              ShellCommand
                .parse(File.read(path))
                .commands
                .select { |inner| create?(inner) }
            if creates.any? { |inner|
                 !inner.arguments.include?("--squash-before-merge=false")
               }
              return Decision.new(status: 2, message: MR_SQUASH_MESSAGE)
            end
          end
          nil
        end

        def self.create?(command)
          case command.argv
          in ["glab", "mr", "create", *]
            true
          else
            false
          end
        end

        private_class_method :create?
      end

      module Commit
        def self.call(context)
          command =
            context.program.commands.find do |candidate|
              candidate.git_subcommand == "commit" &&
                candidate.git_arguments.none? do |argument|
                  argument == "--fixup" || argument == "--no-edit"
                end
            end
          return unless command

          path = message_path(command.git_arguments, context.cwd)
          unless path
            return Decision.new(status: 2, message: COMMIT_FILE_MESSAGE)
          end
          unless File.file?(path)
            return Decision.new(status: 2, message: COMMIT_FILE_MESSAGE)
          end
          return if valid_message?(File.read(path))

          Decision.new(status: 2, message: COMMIT_FORMAT_MESSAGE)
        end

        def self.message_path(arguments, cwd)
          index = arguments.index("-F")
          path = arguments.at(index + 1) if index
          File.expand_path(path, cwd) if path
        end

        def self.valid_message?(message)
          subject, separator, *body = message.lines(chomp: true)
          /\A[[:upper:]]/.match?(subject) && subject.length <= 50 &&
            !subject.end_with?(".") &&
            (
              separator.nil? ||
                (separator.empty? && body.all? { |line| line.length <= 72 })
            )
        end

        private_class_method :message_path, :valid_message?
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
                  "BLOCKED: this session runs in #{context.cwd}. Use the session host's worktree tool (Claude Code: EnterWorktree) with path #{target}, then rerun the command without cd.\n"
              )
            )
          end
          nil
        end
      end

      private_constant :BLOCKED_MESSAGE,
                       :CHANGE_WRITING_MESSAGE,
                       :ATTRIBUTION_MESSAGE,
                       :COMMIT_FILE_MESSAGE,
                       :COMMIT_FORMAT_MESSAGE,
                       :MR_SCRIPT_MESSAGE,
                       :MR_SQUASH_MESSAGE,
                       :DEVENV_DETACH_MESSAGE,
                       :DEVENV_ROOT_MESSAGE,
                       :UNSUPPORTED_MESSAGE,
                       :SHELL_EDIT_REASON,
                       :COAUTHOR_ATTRIBUTION,
                       :LINEAR_WRITE,
                       :LINEAR_PROSE_KEYS,
                       :UnsupportedShell,
                       :Git,
                       :ShellEdit,
                       :Devenv,
                       :ChangeWriting,
                       :MergeRequest,
                       :Commit,
                       :Attribution,
                       :Worktree
    end

    private_constant :Decision, :Context, :Policies
  end
end
