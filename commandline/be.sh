#!/bin/bash

# Path to savvato.yaml
savvato_yaml="$HOME/src/savvato.yaml"

# Extract the current project name from savvato.yaml
current_project=$(yq e '.projects.current-project' $savvato_yaml)

# Check if the project is listed under frontend
if yq e ".frontend | has(\"$current_project\")" $savvato_yaml > /dev/null; then
    project_type="frontend"
elif yq e ".backend | has(\"$current_project\")" $savvato_yaml > /dev/null; then
    project_type="backend"
else
    echo "Current project is neither frontend nor backend."
    exit 1
fi

case $project_type in
    "frontend")
        # Get the list of API dependencies for the frontend project
        dependencies=($(yq e ".frontend.\"$current_project\".api-dependencies[]" $savvato_yaml))

        # Determine the next dependency to switch to
        for dep in "${dependencies[@]}"; do
            dep_directory="$HOME/src/$dep"
            if [[ "$PWD" != "$dep_directory" ]]; then
                # Output the dependency's directory path
                echo "$dep_directory"
                exit 0
            fi
        done
        echo "No further dependencies to switch to."
        ;;
    "backend")
        # Output the backend project's directory path
        echo "$HOME/src/$current_project"
        ;;
esac
