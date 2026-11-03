require "tmpdir"

module Repositories
  def with_repositories
    Dir.mktmpdir do |home|
      %w[backend renovate].each do |name|
        git("init", "--quiet", "--initial-branch=main", "#{home}/Code/#{name}")
      end
      git(
        "-C",
        "#{home}/Code/backend",
        "-c",
        "user.name=Agent",
        "-c",
        "user.email=agent@example.com",
        "-c",
        "maintenance.auto=false",
        "commit",
        "--quiet",
        "--allow-empty",
        "-m",
        "Start"
      )
      yield "#{home}/Code/backend", home
    end
  end

  def with_backend_worktree
    with_repositories do |backend, home|
      feature = "#{home}/Code/worktrees/backend/feature"
      git("-C", backend, "worktree", "add", "--quiet", "-b", "feature", feature)
      yield feature, home
    end
  end

  def git(*arguments)
    system("git", *arguments, out: File::NULL, err: File::NULL) or
      raise "git #{arguments.join(" ")} failed"
  end
end
