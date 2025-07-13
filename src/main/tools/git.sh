#!/bin/bash

## @function: git.is_clean()
##
## @description: Checks if the working tree is clean (no staged or unstaged changes)
##
## @return: true if clean
git.is_clean() {
  git diff --quiet && git diff --cached --quiet && echo true
}

## @function: git.commit(message)
##
## @description: Commits all staged changes with a message
##
## @return: none
git.commit() {
  local message="$1"
  git commit -am "$message"
}

## @function: git.tag(tag_name)
##
## @description: Tags the current commit with a version tag
##
## @return: none
git.tag() {
  local tag="$1"
  git tag "$tag"
}

## @function: git.push()
##
## @description: Pushes the latest commits and tags to origin
##
## @return: none
git.push() {
  git push && git push --tags
}

## @function: git.add(path?)
##
## @description: Stages the given file/folder for commit. If no path is given, stages all.
##
## @return: none
git.add() {
  local path="$1"
  if [[ -z "$path" ]]; then
    git add .
  else
    git add "$path"
  fi
}

## @function: git.has_conflicts()
##
## @description: Checks if there are unresolved merge conflicts
##
## @return: true if conflicts exist
git.has_conflicts() {
  git diff --name-only --diff-filter=U | grep -q . && echo true
}

## @function: git.merge(branch)
##
## @description: Merges the given branch into the current one
##
## @return: none
git.merge() {
  local branch="$1"
  git merge "$branch"
}

## @function: git.stash_pop()
##
## @description: Pops the last stash and re-applies it
##
## @return: none
git.stash_pop() {
  git stash pop
}

## @function: git.current_branch()
##
## @description: Returns the name of the current branch
##
## @return: string - branch name
git.current_branch() {
  git rev-parse --abbrev-ref HEAD
}

## @function: git.current_commit()
##
## @description: Returns the SHA of the current commit
##
## @return: string - commit SHA
git.current_commit() {
  git rev-parse HEAD
}

## @function: git.has_untracked_files()
##
## @description: Checks for untracked files in the working directory
##
## @return: true if untracked files exist
git.has_untracked_files() {
  [[ -n "$(git ls-files --others --exclude-standard)" ]] && echo true
}

## @function: git.is_repo()
##
## @description: Checks if the current directory is inside a Git repository
##
## @return: true if inside a repo
git.is_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 && echo true
}

## @function: git.clone(url, path?)
##
## @description: Clones a Git repository from the given URL to the optional path
##
## @return: none
git.clone() {
  local url="$1"
  local path="$2"
  if [[ -z "$path" ]]; then
    git clone "$url"
  else
    git clone "$url" "$path"
  fi
}

## @function: git.checkout(branch, create?)
##
## @description: Checks out the given branch. If 'create' is true, it creates the branch before checking out.
##
## @return: none
git.checkout() {
  local branch="$1"
  local create="$2"

  if [[ "$create" == "true" ]]; then
    git checkout -b "$branch"
  else
    git checkout "$branch"
  fi
}
