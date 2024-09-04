#!/bin/bash

# Detect the home directory
home_dir=$(eval echo "~")

# Define the path to the properties file
properties_file="$home_dir/src/savvato.yaml"

# Check if the properties file exists
if [ ! -f "$properties_file" ]; then
	echo "Error: The savvato.yaml file does not exist in $home_dir/src directory."
	exit 1
fi

# Get the active environment from the properties file
function get_active_environment() {
	local active_env=$(yq e '.environment."current-environment"' "$properties_file")
	echo "$active_env"
}

# Get the active project from the properties file
function get_active_project() {
	local active_project=$(yq e '.projects."current-project"' "$properties_file")
	echo "$active_project"
}

function is_frontend_project() {
	current_project=$(get_active_project)
	local is_frontend_project=$(yq e ".frontend | has(\"$current_project\")" "$properties_file")
	echo "$is_frontend_project"
}

function is_backend_project() {
	current_project=$(get_active_project)
	local is_backend_project=$(yq e ".backend | has(\"$current_project\")" "$properties_file")
	echo "$is_backend_project"	
}

# Get the list of backend projects that a frontend project depends on
function get_api_dependencies() {
	local current_project=$(get_active_project)
	local yq_command="yq e '.frontend.\"$current_project\".api-dependencies[]' \"$properties_file\""
	local dependencies=$(eval "$yq_command")
	echo "$dependencies"
}

