#!/bin/bash

source ./savv-shared-functions.sh

# Detect the home directory
home_dir=$(eval echo "~")

# Define the path to the properties file
properties_file="$home_dir/src/savvato.yaml"

# Check if the properties file exists
if [ ! -f "$properties_file" ]; then
	echo "Error: The savvato.yaml file does not exist in $home_dir/src directory."
	exit 1
fi

# Function to start backend API dependencies for the current frontend project
function start_api_dependencies() {
    local current_project=$(get_active_project)
    local api_dependencies=$(get_api_dependencies)

    if [ -n "$api_dependencies" ]; then
        for api_dependency in $api_dependencies; do
            local api_dependency_dir="$home_dir/src/$api_dependency"
            if [ -d "$api_dependency_dir" ]; then
                # Change to the API dependency directory
                cd "$api_dependency_dir"

                # Run 'mvn spring-boot:run' in the background
                mvn spring-boot:run &

                # Switch back to the original directory
                cd "$home_dir"
                echo "Started backend API dependency: $api_dependency"
            else
                echo "Error: Directory for API dependency '$api_dependency' not found in $home_dir/src/"
            fi
        done
    else
        echo "No API dependencies for the current frontend project."
    fi
}

# Function to copy the environment file for the current environment
function copy_environment_file() {
    local current_env=$(get_active_environment)
    local environment_file="./src/app/_environments/environment.$current_env.ts"
    local target_file="./src/app/_environments/environment.ts"
    
    cd "$home_dir/src/$active_project"

    if [ -f "$environment_file" ]; then
        cp "$environment_file" "$target_file"
        echo "Copied environment file: $environment_file => $target_file"
    else
        echo "Error: Environment file not found for $current_env ($environment_file)"
        exit 1
    fi
    
    cd -
}

# Check if the provided value is the 'run' command
active_project=$(get_active_project)

if [ -n "$active_project" ]; then
    # Check if the active project is a frontend project
    property_exists=$(yq eval "select(di == 0).frontend | has(\"$active_project\")" "$properties_file")
    if [ "$property_exists" = "true" ]; then
        # Frontend project
        start_api_dependencies
        copy_environment_file # Call the function to copy the environment file
        echo "Starting frontend project: $active_project"
        cd "$home_dir/src/$active_project"
        ionic serve
    else
        echo "Error: The project '$active_project' does not exist in the properties file or is not a frontend project."
        exit 1
    fi
else
    echo "Error: No current project specified."
    exit 1
fi
exit 0
