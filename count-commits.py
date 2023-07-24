import subprocess
import json
from datetime import datetime, timedelta

def read_previous_output(file_path):
    try:
        with open(file_path, 'r') as file:
            data = json.load(file)
            return data
    except FileNotFoundError:
        return {}

def write_output(file_path, data):
    with open(file_path, 'w') as file:
        json.dump(data, file, indent=4)

def get_commit_authors():
    # Run 'git log' command to get commit history
    git_log_output = subprocess.check_output(['git', 'log', '--pretty=format:%an', '--date=iso'], universal_newlines=True)
    commit_authors = git_log_output.splitlines()
    return commit_authors

def calculate_period_counts(previous_output, commit_authors):
    # Get the last recorded date from previous output, or start from the beginning of the log if not available
    last_recorded_date = previous_output.get('last_recorded_date', None)
    if last_recorded_date:
        last_recorded_date = datetime.strptime(last_recorded_date, '%Y-%m-%d')
    else:
        last_recorded_date = datetime.min

    current_date = datetime.now()
    period_counts = previous_output.get('period_counts', {})

    # Iterate over commit authors and update period counts
    for author in commit_authors:
        if author not in period_counts:
            period_counts[author] = 0
        
        # Check if the commit was made within a new two-week period
        if last_recorded_date <= current_date - timedelta(weeks=2):
            period_counts[author] += 1
    
    # Update the last recorded date
    period_counts['last_recorded_date'] = current_date.strftime('%Y-%m-%d')

    return period_counts

# Path to the previous output file
previous_output_file = 'commit-counts.json'

# Read the previous output file
previous_output = read_previous_output(previous_output_file)

# Get the commit authors from git log
commit_authors = get_commit_authors()

# Calculate the period counts
period_counts = calculate_period_counts(previous_output, commit_authors)

# Write the updated output to the file
write_output(previous_output_file, period_counts)

# Display the updated period counts
for author, count in period_counts.items():
    if author != 'last_recorded_date':
        print(f"{author}: {count}")

