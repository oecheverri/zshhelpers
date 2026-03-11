# --- Git Worktrees Manager ---

_wt_repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || {
    echo "Error: not inside a git repository." >&2
    return 1
  }
}

_wt_main_branch() {
  local ref
  ref=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null) || {
    echo "Error: cannot determine main branch. Run 'git remote set-head origin --auto'." >&2
    return 1
  }
  echo "${ref#origin/}"
}

_wt_ensure_setup() {
  local root=$1
  if [[ ! -d "$root/.worktrees" ]]; then
    mkdir -p "$root/.worktrees"

    if ! git -C "$root" check-ignore -q .worktrees 2>/dev/null; then
      local gitignore="$root/.gitignore"
      if [[ ! -f "$gitignore" ]]; then
        echo ".worktrees" > "$gitignore"
      elif ! grep -qxF '.worktrees' "$gitignore"; then
        echo ".worktrees" >> "$gitignore"
      fi
    fi
  fi
}

worktrees() {
  local cmd="${1:-list}"

  case "$cmd" in
    list)    _wt_list ;;
    switch)  shift; _wt_switch "$@" ;;
    remove)  _wt_remove "$2" ;;
    root)    _wt_root ;;
    *)
      echo "Usage: worktrees [list|switch|remove|root]" >&2
      echo "  list                           List worktrees (default)" >&2
      echo "  switch <name>                  Switch to worktree, creating from main if needed" >&2
      echo "  switch <name> --from <branch>  Switch to worktree, creating from <branch> if needed" >&2
      echo "  remove <name>                  Remove a worktree (with merge safety check)" >&2
      echo "  root                           cd back to the repository root" >&2
      return 1
      ;;
  esac
}

_wt_list() {
  local root
  root=$(_wt_repo_root) || return 1

  local wt_dir="$root/.worktrees"
  if [[ ! -d "$wt_dir" ]]; then
    echo "(no worktrees)"
    return
  fi

  local current_wt=""
  if [[ "$PWD" == "$wt_dir"/* ]]; then
    current_wt="${PWD#$wt_dir/}"
    current_wt="${current_wt%%/*}"
  fi

  local -a entries
  entries=(${wt_dir}/*(N:t))

  if (( ${#entries} == 0 )); then
    echo "(no worktrees)"
    return
  fi

  for name in "${entries[@]}"; do
    if [[ "$name" == "$current_wt" ]]; then
      echo "* $name"
    else
      echo "  $name"
    fi
  done
}

_wt_root() {
  local root
  root=$(_wt_repo_root) || return 1
  cd "$root"
  echo "Switched to repository root: $root"
}

_wt_switch() {
  local name=""
  local from_branch=""

  while (( $# )); do
    case "$1" in
      --from)
        shift
        from_branch="$1"
        ;;
      *)
        name="$1"
        ;;
    esac
    shift
  done

  if [[ -z "$name" ]]; then
    echo "Usage: worktrees switch <name> [--from <branch>]" >&2
    return 1
  fi

  local root wt_path
  root=$(_wt_repo_root)       || return 1
  _wt_ensure_setup "$root"    || return 1

  wt_path="$root/.worktrees/$name"

  if [[ ! -d "$wt_path" ]]; then
    local base_branch
    if [[ -n "$from_branch" ]]; then
      base_branch="$from_branch"
    else
      base_branch=$(_wt_main_branch) || return 1
    fi
    echo "Creating worktree '$name' based on '$base_branch'..."
    git -C "$root" worktree add -b "$name" "$wt_path" "$base_branch" || return 1
  fi

  cd "$wt_path"
  echo "Switched to worktree: $wt_path"
}

_wt_remove() {
  local name="$1"
  if [[ -z "$name" ]]; then
    echo "Usage: worktrees remove <name>" >&2
    return 1
  fi

  local root main_branch wt_path
  root=$(_wt_repo_root)       || return 1
  _wt_ensure_setup "$root"    || return 1
  main_branch=$(_wt_main_branch) || return 1

  wt_path="$root/.worktrees/$name"

  if [[ ! -d "$wt_path" ]]; then
    echo "Error: worktree '$name' does not exist at $wt_path" >&2
    return 1
  fi

  local merged=false
  if git -C "$root" branch --merged "$main_branch" | grep -qw "$name" 2>/dev/null ||
     git -C "$root" branch --merged "origin/$main_branch" | grep -qw "$name" 2>/dev/null; then
    merged=true
  fi

  if [[ "$merged" == false ]]; then
    echo "Warning: branch '$name' is NOT merged into '$main_branch' or 'origin/$main_branch'."
    echo -n "Remove anyway? (y/n): "
    read -r answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
      echo "Aborted."
      return 1
    fi
  fi

  if [[ "$PWD" == "$wt_path"* ]]; then
    cd "$root"
  fi

  git -C "$root" worktree remove --force "$wt_path" || return 1
  git -C "$root" branch -D "$name" 2>/dev/null

  echo "Removed worktree and branch '$name'."
}

# --- Completion ---

_worktrees_existing_names() {
  local root
  root=$(git rev-parse --show-toplevel 2>/dev/null) || return
  local wt_dir="$root/.worktrees"
  [[ -d "$wt_dir" ]] || return
  local -a names
  names=(${wt_dir}/*(N:t))
  compadd -a names
}

_worktrees_branches() {
  local -a branches
  branches=(${(f)"$(git branch -a --format='%(refname:short)' 2>/dev/null)"})
  compadd -a branches
}

_worktrees() {
  local -a subcommands
  subcommands=(
    'list:List worktrees (default)'
    'switch:Switch to worktree, creating if needed'
    'remove:Remove a worktree (with merge safety check)'
    'root:cd back to the repository root'
  )

  if (( CURRENT == 2 )); then
    _describe 'subcommand' subcommands
    return
  fi

  case "${words[2]}" in
    switch)
      if (( CURRENT == 3 )); then
        _worktrees_existing_names
      elif (( CURRENT == 4 )); then
        compadd -- '--from'
      elif [[ "${words[4]}" == "--from" ]] && (( CURRENT == 5 )); then
        _worktrees_branches
      fi
      ;;
    remove)
      if (( CURRENT == 3 )); then
        _worktrees_existing_names
      fi
      ;;
  esac
}

compdef _worktrees worktrees
