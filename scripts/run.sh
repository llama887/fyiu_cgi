#!/bin/bash

# Save the original working directory
ORIGINAL_DIR=$(pwd)

# Resolve absolute paths for helper and config files
SCRIPT_DIR=$(realpath "$(dirname "$0")")
HELPER_DIR="$SCRIPT_DIR/helper"
TOML_FILE="$SCRIPT_DIR/../config.toml"

# Function to parse a TOML key using the helper script
parse_toml_key() {
    local key=$1
    python3 "$HELPER_DIR/parse_toml.py" "$TOML_FILE" "$key"
}

# Check if the TOML file exists
if ! ([ -e "$TOML_FILE" ] && [ -f "$TOML_FILE" ]); then
  echo "Error: TOML file not found: $TOML_FILE"
  exit 1
fi

# Extract server directory and run command
server_directory=$(parse_toml_key "server.directory")
run_command=$(parse_toml_key "server.run_command")

if [ -z "$server_directory" ] || [ -z "$run_command" ]; then
  echo "Error: server.directory or server.run_command is not defined in $TOML_FILE"
  exit 1
fi

# Resolve the absolute path to the server directory
server_path=$(realpath "$SCRIPT_DIR/../$server_directory")

# Verify server directory exists
if [ ! -d "$server_path" ]; then
  echo "Error: Server directory does not exist: $server_path"
  exit 1
fi

# Navigate to the server directory and run the project
echo "Running the project in $server_path..."
cd "$server_path" || {
  echo "Error: Failed to navigate to server directory: $server_path"
  exit 1
}

# Execute the run command
eval "$run_command" || {
  echo "Error: Run command failed: $run_command"
  exit 1
}

# Return to the original directory
cd "$ORIGINAL_DIR"

echo "Run completed successfully!"
