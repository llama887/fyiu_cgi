#!/bin/bash

# Get the target directory from the first argument, or use current directory if not provided
target_dir="${1:-.}"

# Use find to get all directories and store them in an array
mapfile -t directories < <(find "$target_dir" -type d)

# Loop over the array of directories
for dir in "${directories[@]}"; do
    echo "Processing directory: $dir"
    # Add your desired operations here
done