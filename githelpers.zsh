# --- Git Helpers ---

function pushRemote() {

	if git diff --quiet origin ; then
		echo "Remote branch is already up to date"
		return 0
	fi

	branch=$(git name-rev HEAD | awk -F ' ' '{printf $2}')
  	if [ "$branch" = "main" ]; then
  		echo "WILL NOT PUSH TO MAIN"
  	else
		  git push origin $@ $branch
	fi
}
