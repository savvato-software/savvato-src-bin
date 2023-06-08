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

# Get the current environment from the properties file
current_environment=$(yq e '.environment."current-environment"' "$properties_file")

# Exit if the current environment is 'dev'
if [[ $current_environment == "dev" ]]; then
    echo "Current environment is 'dev'. Exiting..."
    exit 0
fi

# Get the current project from the properties file
current_project=$(yq e '.projects."current-project"' "$properties_file")

# Exit if the current project is a backend project
property_exists=$(yq eval "select(di == 0).backend | has(\"$current_project\")" "$properties_file")
if [[ "$property_exists" = "true" ]]; then
    echo "Current project is a backend project. Exiting..."
    exit 0
fi

# Get the frontend project dependencies as an array
frontend_dependencies=($(yq e '.frontend."'"$current_project"'"."api-dependencies"[]' "$properties_file"))

# Find the IP addresses for frontend project dependencies
frontend_ip_addresses=()
for dependency in "${frontend_dependencies[@]}"; do
    ip_address=$(yq e '.backend."'"$dependency"'"."'"$current_environment"'"."host"' "$properties_file")

    frontend_ip_addresses+=("$ip_address")
done

# Define the environment file based on the current environment
environment_file="./src/app/_environments/environment.${current_environment}.ts"

# Check if the environment file exists
if [[ ! -f $environment_file ]]; then
    echo "Environment file $environment_file not found. Unable to update IP addresses."
    exit 1
fi

# Create a temporary copy of the environment file
temp_environment_file="./src/app/_environments/environment_copy.ts"
cp "$environment_file" "$temp_environment_file"

# Update the temporary environment file with the IP addresses and ports
for ((i = 0; i < ${#frontend_dependencies[@]}; i++)); do
    dependency=${frontend_dependencies[$i]}
    ip_address=${frontend_ip_addresses[$i]}
    
    placeholder_ip="${dependency^^}-IP"
    sed -i "s/${placeholder_ip}/${ip_address%%:*}/" "$temp_environment_file"
    
    placeholder_port="${dependency^^}-PORT"
    if [[ $ip_address == *":"* ]]; then
        port=${ip_address#*:}
    else
        port=8080  # Set default port to 8080 if no colon in ip_address
    fi
    sed -i "s|$placeholder_port|$port|" "$temp_environment_file"

done

# Copy the updated temporary environment file to environment.ts
cp "$temp_environment_file" "./src/app/_environments/environment.ts"

echo "Updated environment.ts file with [$current_environment] API addresses:"
echo ""

# Report the new IP addresses
for ((i = 0; i < ${#frontend_dependencies[@]}; i++)); do
    dependency=${frontend_dependencies[$i]}
    ip_address=${frontend_ip_addresses[$i]}
    echo "Dependency: $dependency"
    echo "IP Address: $ip_address"
done

# Remove the temporary environment file
rm "$temp_environment_file"

echo ""

