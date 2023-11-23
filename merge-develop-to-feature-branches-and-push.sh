#!/bin/bash

# Switch to the develop branch
git checkout develop

# Find all branches starting with 'feature/'
for branch in $(git branch --list "feature/*"); do
    echo "--------------------------"
    echo
  # Switch to the feature branch
  git checkout $branch

  git pull

  # Merge the develop branch into the feature branch
  git merge develop

  # Push the updated feature branch to the remote repository
  git push origin $branch
done

# Switch back to the develop branch
git checkout develop
