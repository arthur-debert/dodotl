#! /bin/sh

# shellcheck disable=SC3033
git-branch-rm-both() {
    if [ $# -ne 1 ]; then
        echo "Usage: git-branch-rm-both <branch_name>"
        return 1
    fi

    git branch -D "$1"
    git push origin --delete "$1"
}
