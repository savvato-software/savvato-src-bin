#!/bin/bash

savvato_yaml="$HOME/src/savvato.yaml"
current_project=$(yq e '.projects.current-project' $savvato_yaml)
project_type=""

# Check if the project is listed under frontend
frontend_check=$(yq e ".frontend | has(\"$current_project\")" $savvato_yaml)
if [ "$frontend_check" = "true" ]; then
    project_type="frontend"
fi

# Check if the project is listed under backend if not already found
if [ -z "$project_type" ]; then
    backend_check=$(yq e ".backend | has(\"$current_project\")" $savvato_yaml)
    if [ "$backend_check" = "true" ]; then
        project_type="backend"
    fi
fi

# Handle cases based on project_type
case $project_type in
    "frontend")
        # Output the frontend project's directory path
        echo "$HOME/src/$current_project"
        ;;
    "backend")
        # Get the list of frontend projects
        readarray -t frontend_projects <<< $(yq e '.frontend | keys' $savvato_yaml | cut -c3-999)

        # Initialize a variable to hold the first available frontend project directory
        first_frontend_directory=""

        # Loop through the frontend projects to find the next available dependency
        for frontend_proj in "${frontend_projects[@]}"; do
            frontend_directory="$HOME/src/$frontend_proj"
            # Store the first available frontend project directory
            if [[ -z "$first_frontend_directory" ]]; then
                first_frontend_directory="$frontend_directory"
            fi
            # Check if the current backend project is a dependency for the frontend project
    		if yq e ".frontend[\"$frontend_proj\"].api-dependencies[] == \"$current_project\"" $savvato_yaml > /dev/null; then
                # Check if the current directory matches the frontend project directory
                if [[ "$PWD" != "$frontend_directory" ]]; then
                    # Output the frontend project's directory path
                    echo "$frontend_directory"
                    exit 0
                fi
            fi
        done

        # If no match is found, return the first available frontend project directory
        if [[ -n "$first_frontend_directory" ]]; then
            echo "$first_frontend_directory"
        else
            echo "No frontend dependencies found for the backend project."
        fi
        ;;
esac

