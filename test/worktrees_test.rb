require_relative "test_helper"

class WorktreesResolveTest < Minitest::Test
  CANDIDATES = [
    Wtr::Worktrees::Worktree.new(path: "/repo/.worktrees/feature-auth", head: "aaa1111", branch: "feature/auth", main: false),
    Wtr::Worktrees::Worktree.new(path: "/repo/.worktrees/feature-api", head: "bbb2222", branch: "feature/api", main: false),
    Wtr::Worktrees::Worktree.new(path: "/repo/.worktrees/bugfix-login", head: "ccc3333", branch: "bugfix/login", main: false)
  ].freeze

  def test_resolves_exact_match
    assert_equal "feature-auth", resolve("feature-auth").name
  end

  def test_prefers_exact_match_over_prefix
    candidates = CANDIDATES + [worktree("/repo/.worktrees/feature-auth-v2")]

    assert_equal "feature-auth", Wtr::Worktrees.resolve("feature-auth", candidates).name
  end

  def test_resolves_unique_prefix
    assert_equal "bugfix-login", resolve("bugfix").name
  end

  def test_raises_ambiguous_on_shared_prefix
    error = assert_raises(Wtr::Worktrees::Ambiguous) { resolve("feature") }

    assert_equal "ambiguous name 'feature', matches: feature-auth, feature-api", error.message
  end

  def test_raises_not_found_listing_candidates
    error = assert_raises(Wtr::Worktrees::NotFound) { resolve("nope") }

    assert_equal "no worktree matching 'nope' (available: feature-auth, feature-api, bugfix-login)", error.message
  end

  def test_raises_name_required_with_candidate_names_on_blank_query
    [nil, "", "  "].each do |query|
      error = assert_raises(Wtr::Worktrees::NameRequired) { resolve(query) }

      assert_equal ["feature-auth", "feature-api", "bugfix-login"], error.names
    end
  end

  def test_raises_nothing_to_pick_before_checking_the_query
    assert_raises(Wtr::Worktrees::NothingToPick) { Wtr::Worktrees.resolve(nil, []) }
  end

  private

  def resolve(query)
    Wtr::Worktrees.resolve(query, CANDIDATES)
  end

  def worktree(path)
    Wtr::Worktrees::Worktree.new(path: path, head: "ddd4444", branch: nil, main: false)
  end
end

class WorktreeTest < Minitest::Test
  def test_name_is_the_directory_name
    assert_equal "feature-foo", worktree("/repo/.worktrees/feature-foo").name
  end

  def test_short_head
    assert_equal "abc1234", worktree("/repo").short_head
  end

  def test_contains_its_own_path_and_subdirectories
    worktree = worktree("/repo/.worktrees/foo")

    assert worktree.contains?("/repo/.worktrees/foo")
    assert worktree.contains?("/repo/.worktrees/foo/lib")
    refute worktree.contains?("/repo")
  end

  def test_does_not_contain_a_sibling_sharing_its_prefix
    refute worktree("/repo/.worktrees/foo").contains?("/repo/.worktrees/foo-bar")
  end

  private

  def worktree(path)
    Wtr::Worktrees::Worktree.new(path: path, head: "abc1234567890", branch: "main", main: false)
  end
end

class WorktreesTest < TempRepoTest
  def setup
    super
    @worktrees = Wtr::Worktrees.new
  end

  def test_lists_the_main_worktree_first
    create("feature")
    worktrees = Wtr::Worktrees.new.all

    assert_equal [Dir.pwd, worktree_path("feature")], worktrees.map(&:path)
    assert worktrees.first.main?
    refute worktrees.last.main?
  end

  def test_main_is_the_main_worktree
    assert_equal Dir.pwd, @worktrees.main.path
    assert_equal "main", @worktrees.main.branch
  end

  def test_names_exclude_main_unless_aliased
    create("feature")
    worktrees = Wtr::Worktrees.new

    assert_equal ["feature"], worktrees.names
    assert_equal ["feature", "main"], worktrees.names(main_alias: true)
  end

  def test_find_resolves_non_main_worktrees
    create("feature")

    assert_equal worktree_path("feature"), Wtr::Worktrees.new.find("feat").path
  end

  def test_find_never_returns_main_without_the_alias
    assert_raises(Wtr::Worktrees::NothingToPick) { @worktrees.find("main") }
  end

  def test_find_aliases_main_by_name_and_by_main_branch
    TestHelper.run_in("git", "branch", "-m", "main", "trunk")

    assert @worktrees.find("main", main_alias: true).main?
    assert @worktrees.find("trunk", main_alias: true).main?
  end

  def test_create_makes_a_new_branch_from_head
    added = @worktrees.create("feature/foo")

    refute added.existed
    assert_equal worktree_path("feature-foo"), added.path
    assert_equal "feature/foo", branch_in(added.path)
  end

  def test_create_makes_a_new_branch_from_base
    base = TestHelper.run_in("git", "rev-parse", "HEAD")
    TestHelper.run_in("git", "-c", "user.email=test@test.com", "-c", "user.name=Test", "commit", "--allow-empty", "-q", "-m", "second")

    added = @worktrees.create("from-base", base: base)

    assert_equal base, TestHelper.run_in("git", "rev-parse", "HEAD", dir: added.path)
  end

  def test_create_checks_out_an_existing_branch
    TestHelper.run_in("git", "branch", "side")

    added = @worktrees.create("side")

    assert_equal "side", branch_in(added.path)
  end

  def test_create_reports_an_existing_worktree_without_touching_git
    create("feature")

    added = Wtr::Worktrees.new.create("feature")

    assert added.existed
    assert_equal worktree_path("feature"), added.path
  end

  def test_create_ignores_the_worktrees_directory_once
    create("one")
    Wtr::Worktrees.new.create("two")

    exclude = File.read(File.join(Dir.pwd, ".git", "info", "exclude"))
    assert_equal 1, exclude.lines.count { |line| line.strip == ".worktrees/" }
  end

  def test_create_raises_git_error_on_failure
    error = assert_raises(Wtr::Worktrees::GitError) { @worktrees.create("main") }

    refute_empty error.stderr
  end

  def test_remove_keeps_the_branch_by_default
    create("feature")
    worktrees = Wtr::Worktrees.new

    assert_nil worktrees.remove(worktrees.find("feature"))
    refute Dir.exist?(worktree_path("feature"))
    assert_includes worktrees.branches, "feature"
  end

  def test_remove_deletes_an_unmerged_branch_on_request
    create("feature")
    TestHelper.run_in("git", "-c", "user.email=test@test.com", "-c", "user.name=Test", "commit", "--allow-empty", "-q", "-m", "unmerged", dir: worktree_path("feature"))
    worktrees = Wtr::Worktrees.new

    assert_equal "feature", worktrees.remove(worktrees.find("feature"), delete_branch: true)
    refute_includes worktrees.branches, "feature"
  end

  def test_remove_has_no_branch_to_delete_for_a_detached_worktree
    TestHelper.run_in("git", "worktree", "add", "-q", "--detach", worktree_path("detached"))
    worktrees = Wtr::Worktrees.new

    assert_nil worktrees.remove(worktrees.find("detached"), delete_branch: true)
    refute Dir.exist?(worktree_path("detached"))
  end

  def test_remove_refuses_the_main_worktree
    assert_raises(Wtr::Worktrees::Error) { @worktrees.remove(@worktrees.main) }
  end

  def test_branches_and_refs
    TestHelper.run_in("git", "tag", "v1")

    assert_equal ["main"], @worktrees.branches
    assert_equal ["main", "v1"], @worktrees.refs
  end

  private

  def create(branch)
    Wtr::Worktrees.new.create(branch)
  end

  def worktree_path(name)
    File.join(Dir.pwd, ".worktrees", name)
  end

  def branch_in(path)
    TestHelper.run_in("git", "branch", "--show-current", dir: path).strip
  end
end
