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
    echo "Error: .worktrees directory not found. Run 'worktrees setup' first." >&2
    return 1
  fi
}

worktrees() {
  local cmd="${1:-list}"

  case "$cmd" in
    list)    _wt_list ;;
    switch)  _wt_switch "$2" ;;
    remove)  _wt_remove "$2" ;;
    setup)   _wt_setup ;;
    createBasedOn) _wt_create_based_on "$2" "$3" ;;
    *)
      echo "Usage: worktrees [list|switch|remove|setup|createBasedOn]" >&2
      echo "  list                          List all worktrees (default)" >&2
      echo "  switch <name>                 Switch to worktree, creating if needed" >&2
      echo "  remove <name>                 Remove a worktree (with merge safety check)" >&2
      echo "  setup                         Initialize .worktrees dir and .gitignore entry" >&2
      echo "  createBasedOn <branch> <name> Create worktree based on a specific branch" >&2
      return 1
      ;;
  esac
}

_wt_list() {
  local root
  root=$(_wt_repo_root) || return 1
  git -C "$root" worktree list
}

_wt_setup() {
  local root
  root=$(_wt_repo_root) || return 1

  mkdir -p "$root/.worktrees"
  echo "Created $root/.worktrees"

  local gitignore="$root/.gitignore"

  if [[ ! -f "$gitignore" ]]; then
    echo ".worktrees" > "$gitignore"
    echo "Created .gitignore with .worktrees entry."
  elif ! grep -qxF '.worktrees' "$gitignore"; then
    echo ".worktrees" >> "$gitignore"
    echo "Added .worktrees to .gitignore."
  else
    echo ".worktrees already in .gitignore."
  fi
}

_wt_switch() {
  local name="$1"
  if [[ -z "$name" ]]; then
    echo "Usage: worktrees switch <name>" >&2
    return 1
  fi

  local root main_branch wt_path
  root=$(_wt_repo_root)       || return 1
  _wt_ensure_setup "$root"    || return 1

  wt_path="$root/.worktrees/$name"

  if [[ ! -d "$wt_path" ]]; then
    main_branch=$(_wt_main_branch) || return 1
    echo "Creating worktree '$name' based on '$main_branch'..."
    git -C "$root" worktree add -b "$name" "$wt_path" "$main_branch" || return 1
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

  # Check if the branch is merged into the local or remote main branch
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

  # If we're currently inside the worktree being removed, step out
  if [[ "$PWD" == "$wt_path"* ]]; then
    cd "$root"
  fi

  git -C "$root" worktree remove --force "$wt_path" || return 1

  # Clean up the branch if it still exists locally
  git -C "$root" branch -D "$name" 2>/dev/null

  echo "Removed worktree and branch '$name'."
}

_wt_create_based_on() {
  local source_branch="$1"
  local name="$2"

  if [[ -z "$source_branch" || -z "$name" ]]; then
    echo "Usage: worktrees createBasedOn <branch> <name>" >&2
    return 1
  fi

  local root wt_path
  root=$(_wt_repo_root)       || return 1
  _wt_ensure_setup "$root"    || return 1

  wt_path="$root/.worktrees/$name"

  if [[ -d "$wt_path" ]]; then
    echo "Error: worktree '$name' already exists at $wt_path" >&2
    return 1
  fi

  echo "Creating worktree '$name' based on '$source_branch'..."
  git -C "$root" worktree add -b "$name" "$wt_path" "$source_branch" || return 1
  echo "Created worktree at $wt_path"
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
    'list:List all worktrees (default)'
    'switch:Switch to worktree, creating if needed'
    'remove:Remove a worktree (with merge safety check)'
    'setup:Initialize .worktrees dir and .gitignore entry'
    'createBasedOn:Create worktree based on a specific branch'
  )

  if (( CURRENT == 2 )); then
    _describe 'subcommand' subcommands
    return
  fi

  case "${words[2]}" in
    switch)
      if (( CURRENT == 3 )); then
        _worktrees_existing_names
      fi
      ;;
    remove)
      if (( CURRENT == 3 )); then
        _worktrees_existing_names
      fi
      ;;
    createBasedOn)
      if (( CURRENT == 3 )); then
        _worktrees_branches
      elif (( CURRENT == 4 )); then
        _message 'worktree name'
      fi
      ;;
  esac
}

compdef _worktrees worktrees
