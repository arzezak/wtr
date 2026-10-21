module Wtr
  module Commands
    class Ls
      def initialize(worktrees)
        @worktrees = worktrees
      end

      def run(long: false)
        worktrees = @worktrees.all
        return Result.print("no worktrees") if worktrees.empty?

        rows = [header(long)] + worktrees.map { |worktree| row_for(worktree, long) }
        Result.print(render_table(rows))
      end

      private

      def header(long)
        long ? ["BRANCH", "HEAD", "PATH"] : ["BRANCH", "PATH"]
      end

      def row_for(worktree, long)
        columns = [branch_label(worktree)]
        columns << worktree.short_head if long
        columns << tilde(worktree.path)
        columns
      end

      def render_table(rows)
        widths = column_widths(rows)
        lines = rows.map do |row|
          cells = []
          row.each_with_index do |cell, i|
            cells << ((i < widths.size) ? cell.ljust(widths[i]) : cell)
          end
          cells.join("  ")
        end
        lines.join("\n")
      end

      def column_widths(rows)
        (0...rows.first.size - 1).map { |i| rows.map { |row| row[i].size }.max }
      end

      def tilde(path)
        home = Dir.home
        path.start_with?(home) ? "~#{path[home.size..-1]}" : path # standard:disable Style/SlicingWithRange -- Spinel
      end

      def branch_label(worktree)
        label = worktree.branch || "(detached)"
        worktree.main? ? "#{label} *" : label
      end
    end
  end
end
