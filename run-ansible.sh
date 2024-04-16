#!/bin/bash

# Read YAML file
config_file="$HOME/src/savvato.yaml"

# Get the current environment from the YAML file
current_environment=$(yq e '.environment."current-environment"' "$config_file")
echo "Current environment: $current_environment"

# Exit if the current environment is 'dev'
if [[ $current_environment == "dev" ]]; then
    echo "Current environment is 'dev'. Exiting..."
    exit 0
fi

# Get the current project from the YAML file
current_project=$(yq e '.projects."current-project"' "$config_file")
echo "Current project: $current_project"

# Get the EC2 variables from the YAML file
ec2_user=$(yq e '.projects.ec2_user' "$config_file")
ec2_key=$(yq e '.projects.ec2_key' "$config_file")


# Get the host (IP address or domain name) from the YAML file based on the current environment and current project
host=$(yq e ".backend.$current_project.$current_environment.host" "$config_file")

# Validate the host
if [[ -z $host ]]; then
    echo "Host not found for the current project and environment."
    exit 1
fi

# Extract the host value (if it contains a port, remove the port part)
host=$(echo "$host" | cut -d ':' -f 1)

# Check if the host is an IP address or a domain name
if [[ $host =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    ip_address=$host
else
    # Resolve the domain name to an IP address
    ip_address=$(dig +short $host | head -n 1)
fi

# Validate the resolved IP address format
if [[ ! $ip_address =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid IP address or domain resolution failed: $ip_address"
    exit 1
fi


# Change to the project directory
project_directory="$HOME/src/$current_project"
cd "$project_directory" || exit 1
echo "Changed to project directory: $project_directory"

# Update the Ansible inventory file with the IP address
inventory_file="$project_directory/ansible/$current_environment/inventory.yaml"
sed -i "s/ansible_host: .*/ansible_host: $ip_address/" "$inventory_file"
if [[ $? -ne 0 ]]; then
    echo "Error updating the Ansible inventory file."
    exit 1
fi
echo "Updated the Ansible inventory file with the IP $ip_address"

sed -i "s/User=.*/User=$ec2_user/" "$project_directory/ansible/$current_environment/systemd.service"
echo "Updated the systemd service file."

# Run the Ansible playbook
echo "Running Ansible.........."
ansible-playbook -i ./ansible/$current_environment/inventory.yaml -u "$ec2_user" --private-key "$ec2_key" ./ansible/$current_environment/playbook.yaml

