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

# Extract the server directory
server_directory=$(parse_toml_key "server.directory")
if [ -z "$server_directory" ]; then
  echo "Error: server.directory is not defined in $TOML_FILE"
  exit 1
fi

# Navigate to the server directory
server_path=$(realpath "$SCRIPT_DIR/../$server_directory")
cd "$server_path" || {
  echo "Error: Server directory not found: $server_path"
  exit 1
}

# Run the project
echo "Running the project..."
if ! cargo run; then
  echo "Run failed!"
  exit 1
fi
