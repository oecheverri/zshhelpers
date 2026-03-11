# --- Git Helpers ---

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
