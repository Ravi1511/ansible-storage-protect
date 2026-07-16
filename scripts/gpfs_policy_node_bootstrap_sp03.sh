#!/usr/bin/env bash
set -euo pipefail

# Wrapper for PETASCALE-SP03 using the generic bootstrap script.

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Set variables and call the bootstrap script
SERVER_NAME="PETASCALE-SP03" \
NODE_NAME="hsm-client-03-sp03" \
"$SCRIPT_DIR/gpfs_policy_node_bootstrap.sh" "$@"