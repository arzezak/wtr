module Wtr
  module Commands
    class Rm
      def initialize(worktrees)
        @worktrees = worktrees
      end

      def run(query = nil, delete_branch: false)
        worktree = @worktrees.find(query)
        inside = worktree.contains?(Dir.pwd)
        return Result.none if inside && !confirm_removal?(worktree)

        main_path = @worktrees.main.path
        deleted = @worktrees.remove(worktree, delete_branch: delete_branch)
        Log.puts removal_message(worktree, delete_branch, deleted)

        inside ? Result.cd(main_path) : Result.none
      rescue Worktrees::NothingToPick
        Log.puts "no worktrees to remove"
        Result.none
      rescue Worktrees::NameRequired => e
        Log.puts "pass a name (tab-completes): #{e.names.join(", ")}"
        Result.none
      end

      private

      def removal_message(worktree, delete_branch, deleted)
        if deleted
          "removed #{worktree.name} and deleted branch #{deleted}"
        elsif delete_branch
          "removed #{worktree.name} (detached HEAD, no branch to delete)"
        else
          "removed #{worktree.name} (branch preserved)"
        end
      end

      def confirm_removal?(worktree)
        Log.print "you're inside #{worktree.name}, remove and cd to main? [y/n] "
        answer = $stdin.gets
        !answer.nil? && answer.strip.downcase == "y"
      end
    end
  end
end
