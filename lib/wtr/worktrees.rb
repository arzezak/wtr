require "fileutils"
require "open3"

module Wtr
  class Worktrees
    Worktree = Data.define(:path, :head, :branch, :main) do
      def main?
        main
      end

      def name
        File.basename(path)
      end

      def short_head
        head[0, 7]
      end

      def contains?(dir)
        dir == path || dir.start_with?(path + "/")
      end
    end

    Added = Data.define(:path, :existed)

    class Error < StandardError; end

    class GitError < Error
      attr_reader :stderr

      def initialize(stderr)
        @stderr = stderr
        message = stderr.strip
        super(message.empty? ? "git command failed" : message)
      end
    end

    class NothingToPick < Error; end

    class NameRequired < Error
      attr_reader :names

      def initialize(names)
        @names = names
        super("pass a name: #{names.join(", ")}")
      end
    end

    class Ambiguous < Error; end

    class NotFound < Error; end

    def self.resolve(query, candidates)
      raise NothingToPick if candidates.empty?

      names = candidates.map(&:name)
      raise NameRequired.new(names) if query.nil? || query.strip.empty?

      exact = candidates.find { |worktree| worktree.name == query }
      return exact if exact

      matches = candidates.select { |worktree| worktree.name.start_with?(query) }
      return matches.first if matches.size == 1

      if matches.size > 1
        raise Ambiguous, "ambiguous name '#{query}', matches: #{matches.map(&:name).join(", ")}"
      end

      raise NotFound, "no worktree matching '#{query}' (available: #{names.join(", ")})"
    end

    def initialize
      @all = nil
    end

    def all
      @all ||= parse_list(git("worktree", "list", "--porcelain"))
    end

    def main
      all.find(&:main?) || raise(Error, "cannot find the main worktree")
    end

    def names(main_alias: false)
      names = others.map(&:name)
      main_alias ? names + ["main"] : names
    end

    def find(query, main_alias: false)
      return main if main_alias && main_query?(query)

      Worktrees.resolve(query, others)
    end

    def create(branch, base: nil)
      root = File.join(main.path, ".worktrees")
      path = File.join(root, branch.tr("/", "-"))
      return Added.new(path: path, existed: true) if Dir.exist?(path)

      FileUtils.mkdir_p(root)
      ensure_ignored
      if branch_exists?(branch)
        git("worktree", "add", path, branch)
      else
        args = ["worktree", "add", "-b", branch, path]
        args << base if base
        git(*args)
      end
      @all = nil
      Added.new(path: path, existed: false)
    end

    def remove(worktree, delete_branch: false)
      raise Error, "refusing to remove the main worktree" if worktree.main?

      main_path = main.path
      git("worktree", "remove", worktree.path)
      @all = nil
      return nil unless delete_branch && worktree.branch

      # Run from the main repo: the removed worktree may have been the cwd.
      git("-C", main_path, "branch", "-D", worktree.branch)
      worktree.branch
    end

    def branches
      lines(git("branch", "--format=%(refname:short)"))
    end

    def refs
      lines(git("for-each-ref", "--format=%(refname:short)", "refs/heads/", "refs/tags/", "refs/remotes/"))
    end

    private

    def others
      all.reject(&:main?)
    end

    def main_query?(query)
      query == "main" || (!query.nil? && query == main.branch)
    end

    def ensure_ignored
      marker = ".worktrees/"
      exclude_file = git("rev-parse", "--path-format=absolute", "--git-path", "info/exclude")
      if File.exist?(exclude_file)
        return if File.read(exclude_file).lines.any? { |line| line.strip == marker }
      end

      FileUtils.mkdir_p(File.dirname(exclude_file))
      File.open(exclude_file, "a") { |file| file.puts marker }
    end

    def branch_exists?(branch)
      system("git", "show-ref", "--verify", "--quiet", "refs/heads/#{branch}") == true
    end

    def git(*args)
      stdout, stderr, status = Open3.capture3("git", *args)
      raise GitError.new(stderr) unless status.success?

      stdout.strip
    end

    def lines(output)
      output.split("\n").reject(&:empty?)
    end

    def parse_list(output)
      worktrees = []
      output.split("\n\n").each do |stanza|
        # git lists the main worktree first.
        worktree = parse_stanza(stanza, main: worktrees.empty?)
        worktrees << worktree if worktree
      end
      worktrees
    end

    def parse_stanza(stanza, main:)
      path = ""
      head = ""
      branch = nil

      stanza.each_line do |raw|
        line = raw.chomp
        if line.start_with?("worktree ")
          path = line.delete_prefix("worktree ")
        elsif line.start_with?("HEAD ")
          head = line.delete_prefix("HEAD ")
        elsif line.start_with?("branch ")
          branch = line.delete_prefix("branch refs/heads/")
        end
      end
      return nil if path.empty?

      Worktree.new(path: path, head: head, branch: branch, main: main)
    end
  end
end
