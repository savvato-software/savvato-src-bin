#!/bin/bash

# Read the properties file
properties_file="/home/jjames/src/savvato.yaml"
current_project=$(grep "current-project:" "$properties_file" | awk '{print $2}')
current_environment=$(grep "current-environment:" "$properties_file" | awk '{print $2}')

# Exit if current environment is "dev"
if [ "$current_environment" == "dev" ]; then
    echo "Script execution halted because the current environment is 'dev'."
    exit 0
fi

# Check if the current project is under "frontend"
property_exists_frontend=$(yq eval "select(di == 0).frontend.\"$current_project\"" "$properties_file")

if [ "$property_exists_frontend" != "null" ]; then
    # Current project is under "frontend"

    # Change to the directory of the current project
    project_directory="/home/jjames/src/frontend/$current_project"
    cd "$project_directory"

    echo "Changed to directory: $project_directory"

    # Run refresh-env-files.sh script
    refresh_script_path="/home/jjames/src/bin/refresh-env-files.sh"
    if [ -f "$refresh_script_path" ]; then
        echo "Running refresh-env-files.sh script..."
        bash "$refresh_script_path"
        echo "Refresh script completed successfully."
    else
        echo "refresh-env-files.sh script not found."
        exit 1
    fi

    # Remove the www directory
    echo "Removing www directory..."
    rm -rf ./www

    # Run "ng build"
    echo "Running ng build..."
    ng build
    echo "ng build completed successfully."

    # Get the S3 bucket name associated with the current project
    bucket_name=$(yq eval "select(di == 0).frontend.\"$current_project\".$current_environment.\"s3\".\"bucket-name\"" "$properties_file")

    # Check if the bucket name exists
    if [ "$bucket_name" == "null" ]; then
        echo "Bucket name not found for the current project and environment."
        exit 1
    fi

    # Remove files from S3 bucket
    echo "Removing files from S3 bucket: $bucket_name..."
    aws s3 rm "s3://$bucket_name" --recursive --quiet
    echo "Files removed from S3 bucket: $bucket_name"

    # Copy files to S3 bucket
    echo "Copying files to S3 bucket: $bucket_name..."
    aws s3 cp ./www "s3://$bucket_name" --recursive --quiet
    echo "Files copied to S3 bucket: $bucket_name"

elif [ "$property_exists_backend" != "null" ]; then
    # Current project is a backend project

    # Change to the directory of the current project
    project_directory="/home/jjames/src/$current_project"
    cd "$project_directory"

    echo "Changed to directory: $project_directory"

    # Remove the target directory
    echo "Removing target directory..."
    rm -rf ./target
    echo "Target directory removed successfully."

    # Run "mvn clean package"
    echo "Running 'mvn clean package'..."
    mvn clean package
    echo "'mvn clean package' completed successfully."

    # Find the JAR file in the target directory
    jar_file=$(find "$project_directory/target" -name "$current_project*.jar" -type f)

    # Check if the JAR file exists
    if [ ! -f "$jar_file" ]; then
        echo "JAR file not found in the target directory."
        exit 1
    fi

    echo "Deploying JAR file: $jar_file"

    # Get the S3 bucket name for builds
    s3_bucket_name="savvato-builds-bucket"

    # Remove the version info from the JAR file name
    jar_file_name=$(basename "$jar_file")
    jar_file_name_without_version="${jar_file_name%-*}.jar"

    # Copy the JAR file to S3 bucket
    echo "Copying JAR file to S3 bucket: $s3_bucket_name..."
    aws s3 cp "$jar_file" "s3://$s3_bucket_name/$jar_file_name_without_version"
    echo "JAR file copied to S3 bucket: $s3_bucket_name"


    # Call run_ansible.sh script
    run_ansible_script_path="/home/jjames/src/bin/run-ansible.sh"
    if [ -f "$run_ansible_script_path" ]; then
        echo "Running run-ansible.sh script..."
        if bash "$run_ansible_script_path"; then
            echo "run-ansible.sh script completed successfully."
        else
            echo "Error: run-ansible.sh script failed."
            exit 1
        fi
    else
        echo "run-ansible.sh script not found."
        exit 1
    fi

else
    # Current project is neither under "frontend" nor "backend"
    echo "Current project is not under the 'frontend' or 'backend' property."
    exit 1
fi

