module Wtr
  module Commands
    class Cd
      def initialize(worktrees)
        @worktrees = worktrees
      end

      def run(query = nil)
        return cd_previous if query == "-"

        Result.cd(@worktrees.find(query, main_alias: true).path)
      rescue Worktrees::NothingToPick
        Log.puts "only one worktree here, use 'wtr new <branch>' to create another"
        Result.none
      rescue Worktrees::NameRequired => e
        Log.puts e.message
        Result.none
      end

      private

      def cd_previous
        previous = ENV["WTR_PREV"]

        if previous.nil? || previous.strip.empty?
          Log.puts "no previous worktree"
          return Result.none
        end

        unless Dir.exist?(previous)
          Log.puts "previous worktree is gone: #{previous}"
          return Result.none
        end

        Result.cd(previous)
      end
    end
  end
end
