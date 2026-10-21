module Wtr
  class Completion
    def initialize(worktrees)
      @worktrees = worktrees
    end

    def complete(kind)
      candidates = case kind
      when "worktrees"
        @worktrees.names
      when "cd_targets"
        @worktrees.names(main_alias: true)
      when "branches"
        @worktrees.branches
      when "refs"
        @worktrees.refs
      when "subcommands"
        ["cd", "new", "rm", "ls", "help"]
      else
        []
      end
      Result.print(candidates.join("\n"))
    end

    def self.init_script(shell)
      case shell
      when "zsh"
        Result.print(ZSH_INIT_SCRIPT)
      else
        Log.puts "unsupported shell '#{shell}' (available: zsh)"
        Result.none
      end
    end

    ZSH_INIT_SCRIPT = <<~'ZSH'
      wtr() {
        local output
        output=$(command wtr "$@") || return

        if [[ "$output" == cd\ * ]]; then
          export WTR_PREV="$PWD"
          eval "$output"
        elif [[ -n "$output" ]]; then
          print -r -- "$output"
        fi
      }

      _wtr() {
        local -a subcommands=(
          'cd:switch to a worktree'
          'new:create a worktree'
          'rm:remove a worktree'
          'ls:list worktrees'
          'help:show help'
        )

        if (( CURRENT == 2 )); then
          _describe 'subcommand' subcommands
          return
        fi

        case "${words[2]}" in
          cd)
            local -a worktrees
            worktrees=(${(f)"$(command wtr __complete cd_targets)"})
            _describe 'worktree' worktrees
            ;;
          rm)
            local -a worktrees
            worktrees=(${(f)"$(command wtr __complete worktrees)"})
            _describe 'worktree' worktrees
            ;;
          new)
            if (( CURRENT == 3 )); then
              local -a branches
              branches=(${(f)"$(command wtr __complete branches)"})
              _describe 'branch' branches
            elif (( CURRENT == 4 )); then
              local -a refs
              refs=(${(f)"$(command wtr __complete refs)"})
              _describe 'ref' refs
            fi
            ;;
        esac
      }

      compdef _wtr wtr
    ZSH
  end
end
