require "fileutils"

module AgentHooks
  module Worktree
    module Creator
      def self.call(event, env, out, err)
        home = env.fetch("HOME")
        name = event.fetch("name")
        cwd = event.fetch("cwd")
        tool = event.key?("host") ? "enter_worktree" : "EnterWorktree"
        common_dir =
          capture(
            [
              "git",
              "-C",
              cwd,
              "rev-parse",
              "--path-format=absolute",
              "--git-common-dir"
            ]
          )
        unless common_dir
          return(
            fail_with(
              "Could not find the repository for #{cwd}. Start the session from a repository checkout, then run #{tool} again.",
              err
            )
          )
        end

        main_root = File.dirname(common_dir)
        if main_root == "#{home}/Code/dotfiles"
          return(
            fail_with(
              "dotfiles is edited in its main checkout, never in a linked worktree. Continue in #{home}/Code/dotfiles without #{tool}.",
              err
            )
          )
        end

        slug = name.gsub(/[^[:alnum:]._-]/, "-")
        destination =
          "#{home}/Code/worktrees/#{File.basename(main_root)}/#{slug}"
        if File.exist?(destination)
          existing_common_dir =
            capture(
              [
                "git",
                "-C",
                destination,
                "rev-parse",
                "--path-format=absolute",
                "--git-common-dir"
              ]
            )
          if existing_common_dir&.chomp == common_dir.chomp
            out.puts(destination)
            return 0
          end

          return(
            fail_with(
              "Worktree path exists but is not registered with #{main_root}: #{destination}. Choose a different name.",
              err
            )
          )
        end

        origin_head =
          capture(
            [
              "git",
              "-C",
              main_root,
              "symbolic-ref",
              "--quiet",
              "refs/remotes/origin/HEAD"
            ]
          )
        unless origin_head
          execute(
            ["git", "-C", main_root, "remote", "set-head", "origin", "--auto"],
            err
          )
          origin_head =
            capture(
              [
                "git",
                "-C",
                main_root,
                "symbolic-ref",
                "--quiet",
                "refs/remotes/origin/HEAD"
              ]
            )
        end
        base_ref =
          origin_head ? origin_head.chomp.sub(%r{\Arefs/remotes/}, "") : "HEAD"

        FileUtils.mkdir_p(File.dirname(destination))
        branch_exists =
          !capture(
            [
              "git",
              "-C",
              main_root,
              "show-ref",
              "--verify",
              "--quiet",
              "refs/heads/#{name}"
            ]
          ).nil?
        command = ["git", "-C", main_root, "worktree", "add"]
        command += ["-b", name, destination, base_ref] unless branch_exists
        command += [destination, name] if branch_exists
        return 1 unless execute(command, err)

        if File.file?("#{destination}/devenv.nix") &&
             !execute(%w[devenv allow], err, chdir: destination)
          err.puts(
            "devenv allow failed for #{destination}; run it there before using devenv."
          )
        end
        out.puts(destination)
        0
      end

      def self.capture(command)
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

      private_class_method :capture, :execute, :fail_with
    end
    private_constant :Creator
  end
end
