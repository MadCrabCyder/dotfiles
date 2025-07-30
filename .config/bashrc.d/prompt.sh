parse_git_branch() {
  git branch 2>/dev/null | sed -n '/\* /s///p'
}

PS1='\u@\h:\w$(if git rev-parse --git-dir > /dev/null 2>&1; then echo " (\[\e[32m\]$(parse_git_branch)\[\e[0m\])"; fi)\$ '

