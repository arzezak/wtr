module Wtr
  class CLI
    HELP = <<~HELP
      wtr — git worktrees

      USAGE
        wtr [cd] [name]          switch to a worktree (resolve by name, tab-completes)
        wtr new <branch> [base]  create/checkout a worktree, cd into it
        wtr rm [name] [-b]       remove a worktree (-b/--branch also deletes its branch)
        wtr ls [-l]              list all worktrees (-l/--long adds the HEAD sha)
        wtr help                 this text

      WHERE
        worktrees live in <repo>/.worktrees/<branch> (auto git-ignored; slashes become dashes)

      cd
        bare "wtr" is "wtr cd". with a name, resolves by exact match then unique prefix.
        with no name, lists available worktrees.
        "wtr cd main" returns to the main worktree (also matches the main branch name).
        "wtr cd -" returns to the previous worktree.
        errors out if the repo only has one worktree (nothing to switch to).

      new
        branch exists: checks it out into the new worktree
        branch is new: creates it from <base> (default: current HEAD)
        then cd into the worktree.
        note: git refuses a branch already checked out elsewhere (e.g. main).
        pass --no-hooks to skip copy + after_create steps.

      rm
        removes the picked worktree but preserves its branch.
        refuses the main worktree; git refuses if there are uncommitted changes.
        pass -b/--branch to also delete the branch (force-deletes, even if unmerged).
    HELP

    def initialize
      @worktrees = nil
    end

    def run(args)
      dispatch(args).render($stdout)
    rescue => e
      Log.puts(e.message)
      exit 1
    end

    private

    def dispatch(args)
      subcommand = args.empty? ? "cd" : args.shift

      case subcommand
      when "help", "-h", "--help"
        Result.print(HELP)
      when "--version", "-v"
        Result.print("wtr #{VERSION}")
      when "init"
        Completion.init_script(args.first || "zsh")
      when "cd"
        Commands::Cd.new(worktrees).run(args.first)
      when "new"
        dispatch_new(args)
      when "rm"
        dispatch_rm(args)
      when "ls", "list"
        dispatch_ls(args)
      when "__complete"
        Completion.new(worktrees).complete(args.first || "subcommands")
      else
        raise "unknown subcommand '#{subcommand}'\n#{HELP}"
      end
    end

    def dispatch_ls(args)
      long = flag?(args, "-l", "--long")
      reject_unknown_flags(args, "ls")

      Commands::Ls.new(worktrees).run(long: long)
    end

    def dispatch_rm(args)
      delete_branch = flag?(args, "-b", "--branch")
      reject_unknown_flags(args, "rm")

      Commands::Rm.new(worktrees).run(args.first, delete_branch: delete_branch)
    end

    def dispatch_new(args)
      hooks = !flag?(args, "--no-hooks")
      branch = args.shift
      base = args.shift
      raise "usage: wtr new <branch> [base] [--no-hooks]" unless branch

      Commands::New.new(worktrees).run(branch, base, hooks: hooks)
    end

    def flag?(args, *names)
      names.map { |name| args.delete(name) }.compact.any? # Spinel: matz/spinel#9883
    end

    def reject_unknown_flags(args, subcommand)
      unknown = args.find { |arg| arg.start_with?("-") }
      raise "unknown flag '#{unknown}' for #{subcommand}" if unknown
    end

    def worktrees
      @worktrees ||= Worktrees.new
    end
  end
end
