#!/bin/bash

SCRIPT_DIR=$(realpath "$(dirname "$0")")
TOML_FILE="$SCRIPT_DIR/../config.toml"

./build_binaries.sh
./parse_jinja.py "$TOML_FILE"