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

# Extract CGI and bin directories
cgi_directory=$(parse_toml_key "endpoints.cgi_directory")
bin_directory=$(parse_toml_key "endpoints.bin_directory")

if [ -z "$cgi_directory" ] || [ -z "$bin_directory" ]; then
  echo "Error: CGI or BIN directory not defined in $TOML_FILE"
  exit 1
fi

echo "Building files in $cgi_directory and placing binaries in $bin_directory"

# Resolve CGI and BIN directories as absolute paths
cgi_path=$(realpath "$SCRIPT_DIR/../$cgi_directory")
bin_path=$(realpath "$SCRIPT_DIR/../$bin_directory")

# Verify CGI directory
if [ ! -d "$cgi_path" ]; then
  echo "Error: CGI directory does not exist: $cgi_path"
  exit 1
fi

# Ensure bin directory exists
mkdir -p "$bin_path"

# Verify bin directory
if [ ! -d "$bin_path" ]; then
  echo "Error: Failed to create BIN directory: $bin_path"
  exit 1
fi

# Give write permissions to the bin directory
chmod o+w "$bin_path"

# Navigate to CGI directory
cd "$cgi_path" || {
  echo "Error: Failed to navigate to CGI directory: $cgi_path"
  exit 1
}

# Function to dynamically read build instructions
get_build_instruction() {
    local extension=$1
    python3 "$HELPER_DIR/parse_toml.py" "$TOML_FILE" "build_instructions.$extension"
}

# Process files in CGI directory
shopt -s nullglob
for file in *.*; do
    file_extension="${file##*.}"
    file_name="${file%.*}"

    # Get the build instruction for the file's extension
    build_instruction=$(get_build_instruction "$file_extension")

    # Skip if no build instruction is found
    if [ -z "$build_instruction" ]; then
        echo "No build instruction for .$file_extension, skipping $file"
        continue
    fi

    if [[ "$build_instruction" == "\$COPY\$" ]]; then
        # Handle copying case
        echo "Copying $file to $bin_path/$file_name.cgi"
        cp "$file" "$bin_path/$file_name.cgi" || {
            echo "Error: Failed to copy $file"
            exit 1
        }
    else
        # Execute the build instruction
        echo "Executing build instruction for $file"
        command=${build_instruction//\$FILE_NAME\$/$file_name}
        eval "$command" || {
            echo "Error: Failed to build $file"
            exit 1
        }

        # Move the resulting file to the bin directory with a .cgi extension
        if [ -f "$file_name" ]; then
            echo "Moving $file_name to $bin_path/$file_name.cgi"
            mv "$file_name" "$bin_path/$file_name.cgi" || {
                echo "Error: Failed to move $file_name to $bin_path"
                exit 1
            }
        else
            echo "Error: Build did not produce an expected output for $file"
            exit 1
        fi
    fi
done

# Make all files in the bin directory executable
chmod +x "$bin_path"/*

echo "Build completed successfully!"
