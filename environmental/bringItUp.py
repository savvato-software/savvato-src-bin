#!/usr/bin/python

import os
import subprocess
import yaml

def read_properties_file(file_path):
    with open(file_path, 'r') as file:
        properties = yaml.safe_load(file)
    return properties

def update_properties_file(file_path, dependency, ip_address):
    with open(file_path, 'r') as file:
        properties = yaml.safe_load(file)

    properties['backend'][dependency]['staging']['host'] = ip_address

    with open(file_path, 'w') as file:
        yaml.dump(properties, file)

def start_staging_instances(dependencies, properties_file_path, nfsn_script_directory):
    for dependency in dependencies:
        if dependency in properties['frontend'][current_project]['api-dependencies']:
            instance_id = properties['backend'][dependency]['staging']['aws']['instance-id']
            subprocess.run(['aws', 'ec2', 'start-instances', '--instance-ids', instance_id], check=True)

            # Get the public IP address of the newly created EC2 instance
            output = subprocess.check_output(['aws', 'ec2', 'describe-instances', '--instance-ids', instance_id, '--query', 'Reservations[].Instances[].PublicIpAddress', '--output', 'text'])
            ip_address = output.strip().decode('utf-8')

            # Prepare to update DNS
            name = dependency.replace('savvato-', '') + '.staging'
            nfsn_script_path = os.path.join(nfsn_script_directory, 'nearlyfreespeech', 'nfsn.js')
            subprocess.run(['node', nfsn_script_path, name, ip_address], check=True)

            # Update backend staging host property in properties file
            update_properties_file(properties_file_path, dependency, ip_address)

if __name__ == '__main__':
    print('As of April 16 2024, I think you should use the AWS console to do this. It sets DNS IP addresses, etc. Can\'t really think of a reason to use this script any more. If you need to, future self, just delete this comment and exit, be sure the savvato.yaml has the instance id, and you should be good. If you don\'t need to future self, maybe delete this (and the shutItDown) script ??')
    exit(1)

    script_directory = os.path.dirname(os.path.abspath(__file__))

    file_path = os.path.expanduser('~/src/savvato.yaml')
    properties = read_properties_file(file_path)

    current_environment = properties['environment']['current-environment']
    current_project = properties['projects']['current-project']

    if current_environment != 'staging':
        print('Current environment is not staging. Exiting...')
        exit(1)

    frontend_projects = properties['frontend'].keys()

    if current_project not in frontend_projects:
        print('Current project does not appear under the frontend section. Exiting...')
        exit(1)

    dependencies = properties['frontend'][current_project]['api-dependencies']
    start_staging_instances(dependencies, file_path, script_directory)

