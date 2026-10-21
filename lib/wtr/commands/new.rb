require "fileutils"

module Wtr
  module Commands
    class New
      def initialize(worktrees)
        @worktrees = worktrees
      end

      def run(branch, base = nil, hooks: true)
        added = @worktrees.create(branch, base: base)

        if added.existed
          Log.puts "worktree already exists at #{added.path}"
        elsif hooks
          run_hooks(@worktrees.main.path, added.path)
        end

        Result.cd(added.path)
      end

      private

      def run_hooks(main_path, worktree_path)
        config = Config.load(main_path)
        copy_files(config, main_path, worktree_path)
        run_after_create(config, worktree_path)
      end

      def copy_files(config, main_path, worktree_path)
        main_root = File.realpath(main_path)
        worktree_root = File.realpath(worktree_path)

        config.copy.each do |relative_path|
          source = File.expand_path(relative_path, main_path)
          destination = File.expand_path(relative_path, worktree_path)
          unless File.exist?(source)
            Log.puts "copy: skipping #{relative_path} (not found in main worktree)"
            next
          end
          unless within?(File.realpath(source), main_root) && within?(existing_ancestor(destination), worktree_root)
            Log.puts "copy: skipping #{relative_path} (path escapes repo)"
            next
          end
          if File.symlink?(destination)
            Log.puts "copy: skipping #{relative_path} (destination is a symlink)"
            next
          end
          FileUtils.mkdir_p(File.dirname(destination))
          FileUtils.cp(source, destination)
          Log.step("copy", relative_path)
        end
      end

      def within?(path, root)
        path == root || path.start_with?(root + "/")
      end

      def existing_ancestor(path)
        dir = File.dirname(path)
        dir = File.dirname(dir) until File.exist?(dir)
        File.realpath(dir)
      end

      def run_after_create(config, worktree_path)
        env = {"WTR_WORKTREE_NAME" => File.basename(worktree_path)}

        config.after_create.each do |command|
          Log.step("run", command)
          pid = Process.spawn(env, "sh", "-c", command, chdir: worktree_path, out: $stderr, err: $stderr)
          Process.wait(pid)
          status = $?
          unless status.success?
            Log.puts "after_create failed: #{command} (exit #{status.exitstatus})"
            break
          end
        end
      end
    end
  end
end
