# --- Git Helpers ---
#
# Safe wrappers around common git operations.
#
# PUBLIC FUNCTIONS
# ----------------
#
# pushRemote [flags...]
#   Push the current branch to origin with upstream tracking (-u).
#   Refuses to push 'main' unless a force flag is given.
#
#   Flags:
#     -f, --force, --force-with-lease, --force-if-includes
#       Override the main-branch safety check (and pass the flag to git push).
#
#     Any other flags are forwarded directly to `git push`.
#
#   Examples:
#     pushRemote                          # push current branch to origin
#     pushRemote --force-with-lease       # force-push (also bypasses main guard)
#     pushRemote --no-verify              # push, skipping pre-push hooks
#
#   Errors:
#     - Not on a branch (detached HEAD)
#     - On 'main' without a force flag

# =============================================================================
# PUBLIC API
# =============================================================================

function pushRemote() {
  local branch
  branch=$(git branch --show-current) || return 1

  if [[ -z "$branch" ]]; then
    echo "Error: not on a branch (detached HEAD)." >&2
    return 1
  fi

  local force=false
  local -a args
  for arg in "$@"; do
    case "$arg" in
      -f|--force|--force-with-lease|--force-with-lease=*|--force-if-includes)
        force=true
        args+=("$arg")
        ;;
      *)
        args+=("$arg")
        ;;
    esac
  done

  if [[ "$force" == false && "$branch" == "main" ]]; then
    echo "Error: will not push to main. Use -f to override." >&2
    return 1
  fi

  git push -u origin "${args[@]}" "$branch"
}
