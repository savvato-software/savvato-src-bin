#!/bin/bash

# Switch to the develop branch
git checkout develop

# Find all branches starting with 'feature/'
for branch in $(git branch --list "feature/*"); do
  # Switch to the feature branch
  git checkout $branch

  # Merge the develop branch into the feature branch
  git merge develop

  # Push the updated feature branch to the remote repository
  git push origin $branch

  # Switch back to the develop branch
  git checkout develop
done

