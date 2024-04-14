#!/bin/bash

# Function to print error and exit
print_error_and_exit() {
    echo "Error: $1"
    exit 1
}

# Check if IP address parameter is provided
if [ -z "$1" ]; then
    print_error_and_exit "IP address parameter is missing. Usage: $0 <ip_address>"
fi

# Read YAML file
config_file="$HOME/src/savvato.yaml"

# Get EC2 variables from the YAML file
ec2_user=$(yq e '.projects.ec2_user' "$config_file")
ec2_key=$(yq e '.projects.ec2_key' "$config_file")

# Check if private key file exists
if [ ! -f "$ec2_key" ]; then
    print_error_and_exit "Private key file '$ec2_key' not found."
fi

# Check if private key file has correct permissions
if [ "$(stat -c %a "$ec2_key")" != "600" ]; then
    print_error_and_exit "Private key file '$ec2_key' permissions are not set to 600. Please run 'chmod 600 $ec2_key'."
fi

# Update inventory file with the provided IP address
inventory_file="$HOME/src/bin/inventory-generic.yaml"
sed -i "s/ansible_host:.*/ansible_host: $1/" "$inventory_file"

playbook_file="$HOME/src/bin/playbook-generic.yaml"

# Run Ansible playbook
EC2USER="$ec2_user" EC2KEYPATH="$ec2_key" ansible-playbook -i "$inventory_file" -u "$ec2_user" --private-key "$ec2_key" $playbook_file


