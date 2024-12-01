#!/bin/bash

SCRIPT_DIR=$(realpath "$(dirname "$0")")
TOML_FILE="$SCRIPT_DIR/../config.toml"

"$SCRIPT_DIR"/build_binaries.sh
"$SCRIPT_DIR"/parse_jinja.py "$TOML_FILE"