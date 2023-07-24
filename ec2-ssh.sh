#!/bin/bash

# Read YAML file
config_file="$HOME/src/savvato.yaml"

# Get current environment from the YAML file
current_environment=$(yq e '.environment."current-environment"' "$config_file")
echo "Current environment: $current_environment"

# Exit if the current environment is 'dev'
if [[ $current_environment == "dev" ]]; then
    echo "Current environment is 'dev'. Exiting..."
    exit 0
fi

# Get current project from the YAML file
current_project=$(yq e '.projects."current-project"' "$config_file")
echo "Current project: $current_project"

# Get IP address from the YAML file based on the current environment and current project
ip_address=$(yq e ".backend.\"$current_project\".\"$current_environment\".host" "$config_file")
echo "IP address: $ip_address"

if [[ -n $ip_address ]]; then
    # Run SSH command
    ssh_command="ssh -i $(yq e '.projects.ec2_key' "$config_file") $(yq e '.projects.ec2_user' "$config_file")@$ip_address"
    echo "Running SSH command: $ssh_command"
    eval "$ssh_command"
else
    echo "No IP address found for project: $current_project"
fi

