#!/bin/bash
################################################################################
# GPFS Fileset Backup Trigger Script
################################################################################
# This script triggers GPFS fileset backups to SP servers based on
# configuration from Ansible host_vars files.
#
# Usage:
#   ./trigger_gpfs_backup.sh <hsm-client-hostname> [fileset-path]
#
# Examples:
#   ./trigger_gpfs_backup.sh hsm-client-03                    # Backup all configured filesets
#   ./trigger_gpfs_backup.sh hsm-client-03 /gpfs_main/fileset_2  # Backup specific fileset
#
# Prerequisites:
#   - HSM client must be configured (petascale_configure.yml completed)
#   - GPFS must be running
#   - DMAPI must be enabled
#   - SP servers must be configured with storage pools
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration paths
INVENTORY_FILE="$PROJECT_ROOT/playbooks/inventory/petascale.ini"
HOST_VARS_DIR="$PROJECT_ROOT/playbooks/host_vars"

# GPFS command path
GPFS_BIN="/usr/lpp/mmfs/bin"

################################################################################
# Functions
################################################################################

print_header() {
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

usage() {
    cat << EOF
Usage: $0 <hsm-client-hostname> [fileset-path]

Trigger GPFS fileset backups to SP servers.

Arguments:
  hsm-client-hostname   Hostname from inventory (e.g., hsm-client-03)
  fileset-path          Optional: Specific fileset to backup (e.g., /gpfs_main/fileset_2)
                        If not specified, all configured filesets will be backed up

Examples:
  $0 hsm-client-03
  $0 hsm-client-03 /gpfs_main/fileset_2

The script will:
  1. Read configuration from playbooks/host_vars/<hostname>.yml
  2. Connect to the HSM client via SSH
  3. Run mmbackup for each configured fileset
  4. Verify backup completion

Configuration is read from:
  - Inventory: $INVENTORY_FILE
  - Host vars: $HOST_VARS_DIR/<hostname>.yml

EOF
    exit 1
}

get_ansible_host() {
    local hostname="$1"
    grep "^${hostname}" "$INVENTORY_FILE" | awk '{print $2}' | cut -d'=' -f2
}

get_ansible_user() {
    local hostname="$1"
    # First try to get from host line
    local user=$(grep "^${hostname}" "$INVENTORY_FILE" | grep -o 'ansible_user=[^ ]*' | cut -d'=' -f2)
    
    # If not found, get from group vars
    if [ -z "$user" ]; then
        # Determine which group this host belongs to
        local in_hsm_clients=$(grep -A 100 "^\[hsm_clients\]" "$INVENTORY_FILE" | grep -B 100 "^\[" | grep "^${hostname}" || echo "")
        
        if [ -n "$in_hsm_clients" ]; then
            user=$(grep -A 20 "^\[hsm_clients:vars\]" "$INVENTORY_FILE" | grep "^ansible_user=" | cut -d'=' -f2)
        fi
    fi
    
    # Default to root if not found
    echo "${user:-root}"
}

get_ansible_password() {
    local hostname="$1"
    # Try to get from host line
    local password=$(grep "^${hostname}" "$INVENTORY_FILE" | grep -o 'ansible_password=[^ ]*' | cut -d'=' -f2)
    echo "$password"
}

ssh_cmd() {
    local user="$1"
    local host="$2"
    local password="$3"
    shift 3
    local command="$@"
    
    if [ -n "$password" ]; then
        sshpass -p "$password" ssh -o StrictHostKeyChecking=no "$user@$host" "$command"
    else
        ssh "$user@$host" "$command"
    fi
}

parse_sp_servers() {
    local yaml_file="$1"
    
    # Extract sp_servers configuration
    # This is a simplified parser - assumes specific YAML structure
    awk '/^sp_servers:/,/^[^ ]/ {print}' "$yaml_file" | grep -E "(name:|domain:)" | paste -d' ' - - | sed 's/.*name:[[:space:]]*"\([^"]*\)".* domain:[[:space:]]*"\([^"]*\)".*/\1|\2/'
}

################################################################################
# Main Script
################################################################################

# Check arguments
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    print_error "Invalid number of arguments"
    usage
fi

HSM_CLIENT_HOSTNAME="$1"
SPECIFIC_FILESET="${2:-}"
HOST_VARS_FILE="$HOST_VARS_DIR/${HSM_CLIENT_HOSTNAME}.yml"

print_header "GPFS FILESET BACKUP"
echo "HSM Client: $HSM_CLIENT_HOSTNAME"
echo "Date: $(date)"
echo ""

# Validate files exist
if [ ! -f "$INVENTORY_FILE" ]; then
    print_error "Inventory file not found: $INVENTORY_FILE"
    exit 1
fi

if [ ! -f "$HOST_VARS_FILE" ]; then
    print_error "Host vars file not found: $HOST_VARS_FILE"
    print_info "Expected location: $HOST_VARS_FILE"
    exit 1
fi

print_success "Configuration files found"

# Get HSM client connection details
ANSIBLE_HOST=$(get_ansible_host "$HSM_CLIENT_HOSTNAME")
ANSIBLE_USER=$(get_ansible_user "$HSM_CLIENT_HOSTNAME")
ANSIBLE_PASSWORD=$(get_ansible_password "$HSM_CLIENT_HOSTNAME")

if [ -z "$ANSIBLE_HOST" ]; then
    print_error "Failed to find ansible_host for $HSM_CLIENT_HOSTNAME in inventory"
    exit 1
fi

if [ -n "$ANSIBLE_PASSWORD" ]; then
    print_success "HSM Client connection: $ANSIBLE_USER@$ANSIBLE_HOST (password auth)"
else
    print_success "HSM Client connection: $ANSIBLE_USER@$ANSIBLE_HOST (key auth)"
fi
echo ""

# Parse sp_servers configuration
print_info "Reading fileset-to-server mappings from $HOST_VARS_FILE"

# Extract server and domain mappings
MAPPINGS=$(parse_sp_servers "$HOST_VARS_FILE")

if [ -z "$MAPPINGS" ]; then
    print_error "No sp_servers configuration found in $HOST_VARS_FILE"
    print_info "Expected format:"
    print_info "sp_servers:"
    print_info "  - name: \"SERVER_NAME\""
    print_info "    domain: \"/gpfs_path/fileset\""
    exit 1
fi

print_success "Found fileset-to-server mappings:"
echo "$MAPPINGS" | while IFS='|' read -r server_name fileset_path; do
    echo "  $fileset_path → $server_name"
done
echo ""

# Filter mappings if specific fileset requested
if [ -n "$SPECIFIC_FILESET" ]; then
    MAPPINGS=$(echo "$MAPPINGS" | grep "$SPECIFIC_FILESET" || true)
    if [ -z "$MAPPINGS" ]; then
        print_error "Fileset $SPECIFIC_FILESET not found in configuration"
        exit 1
    fi
    print_info "Filtering to specific fileset: $SPECIFIC_FILESET"
    echo ""
fi

# Run backups
BACKUP_COUNT=0
SUCCESS_COUNT=0
FAILED_COUNT=0

while IFS='|' read -r server_name fileset_path; do
    BACKUP_COUNT=$((BACKUP_COUNT + 1))
    
    print_header "BACKUP $BACKUP_COUNT: $fileset_path → $server_name"
    
    # Extract filesystem and fileset name
    FILESYSTEM=$(echo "$fileset_path" | cut -d'/' -f1-3)
    FILESET_NAME=$(basename "$fileset_path")
    
    print_info "Filesystem: $FILESYSTEM"
    print_info "Fileset: $FILESET_NAME"
    print_info "Target Server: $server_name"
    echo ""
    
    # Check if fileset exists
    print_info "Verifying fileset exists..."
    if ! ssh_cmd "$ANSIBLE_USER" "$ANSIBLE_HOST" "$ANSIBLE_PASSWORD" "test -d $fileset_path"; then
        print_error "Fileset path does not exist: $fileset_path"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        echo ""
        continue
    fi
    print_success "Fileset exists"
    
    # Run backup
    print_info "Starting backup..."
    BACKUP_CMD="sudo $GPFS_BIN/mmbackup $fileset_path --scope inodespace --tsm-servers $server_name -t full"
    
    echo "Command: $BACKUP_CMD"
    echo ""
    
    if ssh_cmd "$ANSIBLE_USER" "$ANSIBLE_HOST" "$ANSIBLE_PASSWORD" "$BACKUP_CMD"; then
        print_success "Backup completed successfully!"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        
        # Verify active server binding (optional)
        print_info "Checking active server binding..."
        BINDING=$(ssh_cmd "$ANSIBLE_USER" "$ANSIBLE_HOST" "$ANSIBLE_PASSWORD" "sudo $GPFS_BIN/mmlsattr -L $fileset_path 2>/dev/null | grep 'dmapi.IBMServ' || echo 'Not set'")
        if [ "$BINDING" != "Not set" ]; then
            print_success "Active server binding: $BINDING"
        else
            print_warning "Active server binding not set (files are backed up but binding is at file level)"
        fi
    else
        print_error "Backup failed!"
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
    
    echo ""
    
done <<< "$MAPPINGS"

# Summary
print_header "BACKUP SUMMARY"
echo "Total backups attempted: $BACKUP_COUNT"
echo "Successful: $SUCCESS_COUNT"
echo "Failed: $FAILED_COUNT"
echo ""

if [ $FAILED_COUNT -eq 0 ]; then
    print_success "All backups completed successfully! 🎉"
    exit 0
else
    print_error "Some backups failed. Please check the output above."
    exit 1
fi

# Made with Bob
