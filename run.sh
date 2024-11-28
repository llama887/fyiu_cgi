#!/bin/bash

# Navigate to the server directory
cd "$(dirname "$0")/server" || {
  echo "Server directory not found!"
  exit 1
}

# Build the project
echo "Building the project..."
if ! cargo build; then
  echo "Build failed!"
  exit 1
fi

# Run the project
echo "Running the project..."
if ! cargo run; then
  echo "Run failed!"
  exit 1
fi
