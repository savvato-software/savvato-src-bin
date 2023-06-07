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

# Define the allowed environment options
allowed_envs=("dev" "staging" "prod")

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

# Get the IP address for the current project from the properties file
function get_ip_address() {
	local current_env=$(get_active_environment)
	local current_project=$(get_active_project)
	local ip_address=$(yq e ".backend.\"$current_project\".$current_env.\"backend-ip\"" "$properties_file")
	echo "$ip_address"
}

# Get the list of backend projects that a frontend project depends on
function get_api_dependencies() {
	local current_project=$(get_active_project)
	local yq_command="yq e '.frontend.\"$current_project\".api-dependencies[]' \"$properties_file\""
	local dependencies=$(eval "$yq_command")
	echo "$dependencies"
}

# Update the current environment in the properties file
function update_current_environment() {
	local env=$1
	yq e ".environment.\"current-environment\" = \"$env\"" -i "$properties_file"
}

# Update the current project in the properties file
function update_current_project() {
	local project=$1
	yq e ".projects.\"current-project\" = \"$project\"" -i "$properties_file"
}

# Update the IP address for the current project in the properties file
function update_ip_address() {
	local ip_address=$1
	local current_env=$(get_active_environment)
	local current_project=$(get_active_project)
	yq e ".backend.\"$current_project\".$current_env.\"backend-ip\" = \"$ip_address\"" -i "$properties_file"
}

# Get the environment from the command line argument
if [ $# -lt 1 ]; then
	echo "Please provide an environment option, project name, IP address, or 'show' command."
	exit 1
fi

param=$1

# Check if the provided value is the 'show' command
if [ "$param" = "show" ]; then
	active_env=$(get_active_environment)
	active_project=$(get_active_project)

	if [ -n "$active_project" ]; then
		if yq e ".frontend.\"$active_project\"" "$properties_file" >/dev/null 2>&1; then
			# Frontend project
			api_dependencies=$(get_api_dependencies)
			echo "Active Environment: $active_env"
			echo "Active Project: $active_project"

			if [ -n "$api_dependencies" ]; then
				echo "API Dependencies: $api_dependencies"
			else
				echo "No API Dependencies"
			fi
		elif yq e ".backend.\"$active_project\"" "$properties_file" >/dev/null 2>&1; then
			# Backend project
			ip_address=$(get_ip_address)
			echo "Active Environment: $active_env"
			echo "Active Project: $active_project"

			if [ -n "$ip_address" ]; then
				echo "IP Address: $ip_address"
			else
				echo "No IP Address"
			fi
		else
			echo "Error: The project '$active_project' does not exist in the properties file."
			exit 1
		fi
	else
		echo "Error: No current project specified."
		exit 1
	fi

	# Check if the provided value is an environment option
elif [[ " ${allowed_envs[@]} " =~ " $param " ]]; then
	update_current_environment "$param"
	echo "Successfully updated the current environment to $param."

	# Check if the provided value is a project name
elif yq e '.projects."all-project-names"[]' "$properties_file" | grep -q "^$param$"; then
	update_current_project "$param"
	echo "Successfully updated the current project to $param."

	# Check if the provided value is an IP address (only for backend projects)
elif [[ $param =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(:[0-9]+)?$ || $param =~ ^(localhost|127\.0\.0\.1):[0-9]+$ ]]; then
	active_project=$(get_active_project)

	if yq e ".backend.\"$active_project\"" "$properties_file" >/dev/null 2>&1; then
		update_ip_address "$param"
		echo "Successfully updated the IP address for $active_project to $param."
	else
		echo "Error: No current project specified or the current project is not a backend project."
		exit 1
	fi

	# Invalid value provided
else
	echo "Invalid argument. Please provide an environment option, project name, IP address, or 'show' command."
	exit 1
fi
