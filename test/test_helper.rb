require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "open3"
require_relative "../lib/wtr"

module TestHelper
  BINARY_PATH = File.expand_path(ENV["WTR_BIN"] || "exe/wtr", File.expand_path("..", __dir__))
  CLEAN_ENV = {"RUBYOPT" => nil, "BUNDLE_GEMFILE" => nil}.freeze

  def self.create_temp_repo
    dir = File.realpath(Dir.mktmpdir("wtr-test"))
    FileUtils.cp_r(File.join(template_repo, "."), dir)
    dir
  end

  def self.template_repo
    @template_repo ||= begin
      dir = File.realpath(Dir.mktmpdir("wtr-template"))
      run_in("git", "init", "-q", "-b", "main", dir: dir)
      run_in("git", "config", "maintenance.auto", "false", dir: dir)
      run_in("git", "config", "gc.auto", "0", dir: dir)
      File.write(File.join(dir, "README.md"), "test repo")
      run_in("git", "add", ".", dir: dir)
      commit("initial", dir: dir)
      Minitest.after_run { FileUtils.rm_rf(dir) }
      dir
    end
  end

  def self.commit(message, dir: Dir.pwd)
    run_in("git", "-c", "user.email=test@test.com", "-c", "user.name=Test", "commit", "--allow-empty", "-q", "-m", message, dir: dir)
  end

  def self.run_in(command, *args, dir: Dir.pwd)
    status, stdout, stderr = capture(command, args, dir)
    raise "#{command} #{args.join(" ")} failed in #{dir}: #{stderr}" unless status.success?

    stdout
  end

  def self.run_wtr(*args, dir: Dir.pwd)
    status, stdout, stderr = capture(BINARY_PATH, args, dir)
    [status.exitstatus, stdout, stderr]
  end

  def self.capture(command, args, dir)
    stdout, stderr, status = Open3.capture3(CLEAN_ENV, command, *args, chdir: dir)
    [status, utf8(stdout).strip, utf8(stderr).strip]
  end

  def self.utf8(text)
    text.dup.force_encoding(Encoding::UTF_8)
  end
end

class TempRepoTest < Minitest::Test
  def setup
    @previous_dir = Dir.pwd
    @repo_dir = TestHelper.create_temp_repo
    Dir.chdir(@repo_dir)
  end

  def teardown
    Dir.chdir(@previous_dir)
    FileUtils.rm_rf(@repo_dir)
  end

  private

  def create_worktree(branch)
    Wtr::Worktrees.new.create(branch).path
  end

  def worktree_path(name)
    File.join(Dir.pwd, Wtr::Worktrees::DIRECTORY, name)
  end
end
