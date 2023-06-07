#!/bin/bash

# Check if a port number is provided
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <port>"
  exit 1
fi

# Get the port number from command-line argument
port=$1

# Find the process ID using the provided port number
pid=$(lsof -t -i :$port)

if [[ -z $pid ]]; then
  echo "No process is running on port $port"
else
  # Kill the process
  kill -9 $pid
  echo "Process with ID $pid has been terminated"
fi

