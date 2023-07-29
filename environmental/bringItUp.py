import os
import subprocess
import yaml

def read_properties_file(file_path):
    with open(file_path, 'r') as file:
        properties = yaml.safe_load(file)
    return properties

def start_staging_instances(dependencies):
    for dependency in dependencies:
        if dependency in properties['frontend'][current_project]['api-dependencies']:
            instance_id = properties['backend'][dependency]['staging']['aws']['instance-id']
            subprocess.run(['aws', 'ec2', 'start-instances', '--instance-ids', instance_id], check=True)

            # Get the public IP address of the newly created EC2 instance
            output = subprocess.check_output(['aws', 'ec2', 'describe-instances', '--instance-ids', instance_id, '--query', 'Reservations[].Instances[].PublicIpAddress', '--output', 'text'])
            ip_address = output.strip().decode('utf-8')

            # Prepare to update DNS
            name = dependency.replace('savvato-', '') + '.staging'
            subprocess.run(['node', './environmental/nearlyfreespeech/nfsn.js', name, ip_address], check=True)

if __name__ == '__main__':
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
    start_staging_instances(dependencies)

