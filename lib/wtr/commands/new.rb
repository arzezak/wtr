require "fileutils"

module Wtr
  module Commands
    class New
      def initialize(worktrees)
        @worktrees = worktrees
      end

      def run(branch, base = nil, hooks: true)
        main_path = @worktrees.main.path
        added = @worktrees.create(branch, base: base)

        if added.existed
          Log.puts "worktree already exists at #{added.path}"
        elsif hooks
          run_hooks(main_path, added.path)
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
        config.copy.each do |relative_path|
          source = File.expand_path(relative_path, main_path)
          destination = File.expand_path(relative_path, worktree_path)
          unless source.start_with?(main_path + "/")
            Log.puts "copy: skipping #{relative_path} (path escapes repo)"
            next
          end
          unless File.exist?(source)
            Log.puts "copy: skipping #{relative_path} (not found in main worktree)"
            next
          end
          FileUtils.mkdir_p(File.dirname(destination))
          FileUtils.cp(source, destination)
          Log.step("copy", relative_path)
        end
      end

      def run_after_create(config, worktree_path)
        env = hook_env(worktree_path)

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

      def hook_env(worktree_path)
        {"WTR_WORKTREE_NAME" => File.basename(worktree_path)}
      end
    end
  end
end
