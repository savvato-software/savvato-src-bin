#!/bin/bash

# Read YAML file
config_file="$HOME/src/savvato.yaml"

# Get current environment
current_env=$(yq eval '.environment."current-environment"' "$config_file")
echo "Current environment: $current_env"

# Get current project
current_project=$(yq eval '.projects."current-project"' "$config_file")
echo "Current project: $current_project"

# Get IP address based on environment and project
ip_address=$(yq eval ".$current_project.$current_env.backend-ip" "$config_file")
echo "IP address: $ip_address"

if [[ -n $ip_address ]]; then
        # Run SSH command
            ssh_command="ssh -i ~/Downloads/ec2keypair1.pem ubuntu@$ip_address"
                echo "Running SSH command: $ssh_command"
                    eval "$ssh_command"
                else
                        echo "No IP address found for project: $current_project"
fi



