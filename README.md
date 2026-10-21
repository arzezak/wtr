# 🌳💻 wtr

A small Ruby CLI for managing git worktrees. A port of [wt](https://github.com/arzezak/wt) from Crystal to Ruby.

## Who this is for

wtr is for people who want to create, switch between, and remove worktrees by hand from the terminal, and keep an eye on what exists. If you want manual control over your worktrees rather than delegating that to automation, wtr is for you.

## Install

```sh
gem install wtr
```

Add to your `.zshrc`:

```sh
eval "$(command wtr init zsh)"
```

Reload your shell (`exec zsh`) and you're set.

## Usage

Switch to a worktree (exact or unique-prefix match, tab-completes):

```sh
wtr [name]
wtr cd <name>
wtr cd main    # back to the main worktree (also matches the main branch name)
wtr cd -       # back to the previous worktree
```

Create a worktree, optionally from a base ref:

```sh
wtr new <branch> [base]
```

When the branch exists, `wtr new` checks it out into a new worktree. When the branch is new, it creates it from `[base]`, or from the current `HEAD` if no base is provided. Either way, it switches into the worktree when it finishes.

Remove a worktree (branch preserved):

```sh
wtr rm [name]
```

Pass `-b`/`--branch` to also delete the worktree's branch. This force-deletes it, so it works even when the branch isn't merged:

```sh
wtr rm [name] -b
```

List worktrees (`-l`/`--long` adds the HEAD sha):

```sh
wtr ls
```

Other commands:

```sh
wtr help
wtr --version
```

### Resolution

When you pass a name, `wtr` resolves it directly: exact match first, then unique prefix, then error with candidates.

When you omit the name, `wtr` lists the available worktrees. `wtr cd main` returns to the main worktree, and `wtr cd -` returns to the worktree you came from.

### Tab completion

Tab completion is set up automatically by `wtr init zsh`. It completes:

- `wtr cd <tab>` / `wtr rm <tab>`: worktree names
- `wtr new <tab>`: branch names
- `wtr new <branch> <tab>`: branch/ref names for the base

## Configuration

Per-repo `.wtr.yml` (committed, shared with the team) with an optional `.wtr.local.yml` override (gitignored, personal). Global defaults in `~/.config/wtr/config.yml`. Merge order: global, repo, local.

```yaml
copy:
  - .env
  - .env.local
  - config/master.key

after_create:
  - bundle install
  - yarn install
```

### `copy`

Files to copy from the main worktree into the new one. These are typically gitignored, so they don't come across with the checkout. Missing sources are skipped with a warning.

### `after_create`

Commands run in the new worktree's directory, in order, streaming output. Stops on first non-zero exit. The worktree is already created, so it stays in place for you to fix manually.

Each command is announced on stderr with a 🌳 prefix (as are `copy` files) so it's easy to tell wtr's own output apart from the command's.

Each command runs with `WTR_WORKTREE_NAME` set to the worktree's directory name (e.g. `feature-foo`), useful for isolating per-worktree resources like a database name.

For example, giving each worktree its own Rails development/test database:

```yaml
after_create:
  - |
    cat > .env.local << ENV
    DB_DATABASE=${WTR_WORKTREE_NAME}_development
    DB_TEST_DATABASE=${WTR_WORKTREE_NAME}_test
    ENV
  - bundle install
  - yarn install
  - bin/rails db:create db:schema:load
```

### `--no-hooks`

Skip all copy and after_create steps on `wtr new`.

### Trust model

`.wtr.yml` can be committed to a repo, and `after_create` runs arbitrary shell commands. This is the same trust model as Makefiles and npm scripts: review `.wtr.yml` before running `wtr new` in an untrusted repo, or pass `--no-hooks`.

## Shell integration

### The cd problem

A program can't `cd` your shell (it's a child process). So `wtr` is an **executable + thin shim**, like zoxide or rbenv:

- The **executable** holds all logic (resolve paths, create/remove worktrees, format output).
- A tiny **shell function** calls the executable and `eval`s its stdout for navigation commands.

Both are named `wtr`. The function shadows the executable for interactive use and delegates with `command wtr` (which bypasses functions and runs the executable on PATH).

### Stdout protocol

The executable emits two kinds of output on stdout:

1. **Directives** the shim `eval`s (e.g. `cd <path>`)
2. **Plain text** the shim prints as-is (ls, help, messages)

Errors and human messages go to stderr so they never get `eval`d and hook output (bundle install, etc.) streams live.

## Worktree conventions

- Worktrees live in `<repo>/.worktrees/<branch>`.
- `/` in branch names becomes `-` for the directory (`feature/foo` becomes `.worktrees/feature-foo`).
- `.worktrees/` is added to `.git/info/exclude` (local-only, never the committed `.gitignore`).

## Development

```sh
bin/setup
bundle exec rake   # tests + standard
```

The unit tests exercise the library directly; the command tests drive `exe/wtr` in throwaway git repos. Point `WTR_BIN` at another executable to run them against it instead.

The code sticks to the Ruby subset supported by [Spinel](https://github.com/matz/spinel), Matz's ahead-of-time compiler, so it can also be compiled to a native binary. Keep new code inside that subset.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
