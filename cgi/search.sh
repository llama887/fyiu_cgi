#!/bin/bash

# Set the content directory relative to this script
CONTENT_DIR="../content"

# Check if the content directory exists
if [ ! -d "$CONTENT_DIR" ]; then
    echo "Content directory not found!"
    exit 1
fi

# Output the HTTP headers
echo "Content-Type: text/html"
echo ""

# Start the HTML document
echo "<!DOCTYPE html>"
echo "<html lang='en'>"
echo "<head><title>Content List</title></head>"
echo "<body>"
echo "<h1>Available Content</h1>"

# Generate the unordered list
echo "<ul>"
for file in "$CONTENT_DIR"/*; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        echo "<li>$filename</li>"
    fi
done
echo "</ul>"

# End the HTML document
echo "</body>"
echo "</html>"
