#!/bin/bash

# Detect the home directory
home_dir=$(eval echo "~")

source $home_dir/src/bin/savv-shared-functions.sh

# Define the path to the properties file
properties_file="$home_dir/src/savvato.yaml"

# Check if the properties file exists
if [ ! -f "$properties_file" ]; then
	echo "Error: The savvato.yaml file does not exist in $home_dir/src directory."
	exit 1
fi

# Define the allowed environment options
allowed_envs=("dev" "staging" "prod")

# Get the IP address for the current project from the properties file
function get_ip_address() {
	local current_env=$(get_active_environment)
	local current_project=$(get_active_project)
	local ip_address=$(yq e ".backend.\"$current_project\".$current_env.\"host\"" "$properties_file")
	echo "$ip_address"
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
	yq e ".backend.\"$current_project\".$current_env.\"host\" = \"$ip_address\"" -i "$properties_file"
}


# Function to check if the provided value is a valid AWS instance ID
function is_valid_instance_id() {
    local value=$1
    [[ $value =~ ^i-[0-9a-f]{17}$ ]]
}

# Function to update AWS instance ID in the properties file
function update_aws_instance_id() {
    local instance_id=$1
    local current_env=$(get_active_environment)
    local current_project=$(get_active_project)
    yq e ".backend.\"$current_project\".$current_env.aws.\"instance-id\" = \"$instance_id\"" -i "$properties_file"
}

# Function to execute the environment change script/command
function execute_env_change_script() {
    local new_env=$1
    local current_project=$(get_active_project)
    local script_path="$home_dir/src/$current_project/bin/savv-sh/becomes-current-environment"

    if [ -f "$script_path" ]; then
#        echo "Executing environment change script for $current_project with parameter $new_env"
        bash "$script_path" "$new_env"
    else
        echo "WARN: Expected to find a file, becomes-current-environment, a bash script which would run for the current project when the environment changes; to copy files into place, etc.."
    fi
}

# Get the environment from the command line argument
if [ $# -lt 1 ]; then
	echo "Please provide an environment option, project name, IP address, EC2 instance ID or 'show' command."
	exit 1
fi

param=$1

# Check if the provided value is the 'show' command
if [ "$param" = "show" ]; then
	active_env=$(get_active_environment)
	active_project=$(get_active_project)

	if [ -n "$active_project" ]; then
		# Check if the active project is a frontend project
		property_exists=$(yq eval "select(di == 0).frontend | has(\"$active_project\")" "$properties_file")
		if [ "$property_exists" = "true" ]; then
			# Frontend project
			api_dependencies=$(get_api_dependencies)
			echo "Type: Frontend"
			echo "Active Environment: $active_env"
			echo "Active Project: $active_project"

			if [ -n "$api_dependencies" ]; then
				echo "API Dependencies: $api_dependencies"
			else
				echo "No API Dependencies"
			fi
		else
			# Check if the active project is a backend project
			property_exists=$(yq eval "select(di == 0).backend | has(\"$active_project\")" "$properties_file")
			if [ "$property_exists" = "true" ]; then
				# Backend project
				ip_address=$(get_ip_address)
				echo "Type: Backend"
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
		fi
	else
		echo "Error: No current project specified."
		exit 1
	fi

	# Check if the provided value is an environment option
elif [[ " ${allowed_envs[@]} " =~ " $param " ]]; then
	update_current_environment "$param"

	# Execute the environment change script with the new environment as parameter
  execute_env_change_script "$param"

	echo "Successfully updated the current environment to $param."

	# Check if the provided value is a project name
elif yq e '.projects."all-project-names"[]' "$properties_file" | grep -q "^$param$"; then
	update_current_project "$param"
	echo "Successfully updated the current project to $param."

# Check if the provided value is an IP address (only for backend projects)
elif [[ $param =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(:[0-9]+)?$ || $param =~ ^(localhost|127\.0\.0\.1):[0-9]+$ ]]; then
    active_project=$(get_active_project)

    # Check if the active project is a frontend project
    is_frontend_project=$(is_frontend_project)
    if [ "$is_frontend_project" = "true" ]; then
        echo "$active_project is a frontend project. Cannot set an IP address for it."
        exit 0
    fi

    # Check if the active project is a backend project
    is_backend_project=$(is_backend_project)
    if [ "$is_backend_project" = "true" ]; then
        update_ip_address "$param"
        echo "Successfully updated the IP address for $active_project to $param."
    else
        echo "Error: No current project specified or the current project is not a backend project."
        exit 1
    fi
    
# Check if the provided value is a valid AWS instance ID
elif is_valid_instance_id "$param"; then
    current_env=$(get_active_environment)
    current_project=$(get_active_project)

    # Check if the current project is a backend project
    is_backend_project=$(is_backend_project)

    # Ensure current environment is not 'dev' and the project is a backend project
    if [ "$current_env" != "dev" ] && [ "$is_backend_project" = "true" ]; then

        update_aws_instance_id "$param"
        echo "Successfully updated the AWS instance ID for $current_project in environment $current_env to $param."
    else
        echo "Error: Either the environment is 'dev' or the current project is not a backend project."
        exit 1
    fi

# Check if the provided value is "."
elif [ "$param" = "." ]; then
	if [ -f "package.json" ]; then
		project_name=$(sed -n '2p' package.json | awk -F '"' '{print $4}')
		if yq e '.projects."all-project-names"[]' "$properties_file" | grep -q "^$project_name$"; then
			update_current_project "$project_name"
			echo "Successfully updated the current project to $project_name."
		else
			echo "Error: The project name '$project_name' does not exist in the 'all-project-names' list in savvato.yaml."
			exit 1
		fi
	elif [ -f "pom.xml" ]; then
		project_name=$(grep -oP '<artifactId>\K[^<]*' pom.xml | sed -n '2p')
		if yq e '.projects."all-project-names"[]' "$properties_file" | grep -q "^$project_name$"; then
			update_current_project "$project_name"
			echo "Successfully updated the current project to $project_name."
		else
			echo "Error: The project name '$project_name' does not exist in the 'all-project-names' list in savvato.yaml."
			exit 1
		fi
	else
		echo "Error: No package.json or pom.xml file found."
		exit 1
	fi
# Invalid value provided
else
    echo "Invalid argument. Please provide an environment option, project name, IP address, AWS instance ID, or 'show' command."
    exit 1
fi

