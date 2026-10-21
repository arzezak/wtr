module Wtr
  module Commands
    class Rm
      def initialize(resolver, git)
        @resolver = resolver
        @git = git
      end

      def run(query = nil, delete_branch: false)
        entry = @resolver.pick(query, "no worktrees to remove")
        return Result.none unless entry

        inside = inside_worktree?(entry)
        return Result.none if inside && !confirm_removal?(entry)

        @git.run("worktree", "remove", entry.path)

        if delete_branch
          delete_branch_for(entry)
        else
          Log.puts "removed #{entry.name} (branch preserved)"
        end

        inside ? Result.cd(@resolver.main_entry.path) : Result.none
      end

      private

      def delete_branch_for(entry)
        branch = entry.branch

        unless branch
          Log.puts "removed #{entry.name} (detached HEAD, no branch to delete)"
          return
        end

        # Run from the main repo: the removed worktree may have been the cwd.
        @git.run("-C", @resolver.main_entry.path, "branch", "-D", branch)
        Log.puts "removed #{entry.name} and deleted branch #{branch}"
      end

      def inside_worktree?(entry)
        Dir.pwd.start_with?(entry.path)
      end

      def confirm_removal?(entry)
        Log.print "you're inside #{entry.name}, remove and cd to main? [y/n] "
        answer = $stdin.gets
        !answer.nil? && answer.strip.downcase == "y"
      end
    end
  end
end
