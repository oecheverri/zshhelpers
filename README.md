# ZSHHelpers

A collection of ZSH shell functions for safer, more ergonomic git workflows.

## What's included

| File | Function | Description |
|------|----------|-------------|
| `githelpers.zsh` | `pushRemote` | Push the current branch to origin with guardrails against accidental pushes to main |
| `worktrees.zsh` | `worktrees` | Manage git worktrees from a single command — create, switch, list, and remove |

## Installation

Source the files you want in your `.zshrc`:

```zsh
source /path/to/ZSHHelpers/githelpers.zsh
source /path/to/ZSHHelpers/worktrees.zsh
```

## Usage

### `pushRemote`

Push the current branch to `origin` with upstream tracking. Refuses to push `main` unless you pass a force flag.

```zsh
pushRemote                        # push current branch
pushRemote --force-with-lease     # force-push (bypasses main guard)
```

### `worktrees`

Manage git worktrees stored under `<repo>/.worktrees/`. The directory is automatically git-ignored.

```zsh
worktrees                         # list all worktrees
worktrees switch my-feature       # create & cd into 'my-feature' (branched from main)
worktrees switch fix --from dev   # create & cd into 'fix' (branched from dev)
worktrees remove my-feature       # remove worktree (warns if unmerged)
worktrees root                    # cd back to repository root
```

Tab completion is included for subcommands, worktree names, and branch names.

## License

MIT
