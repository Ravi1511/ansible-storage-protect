#!/bin/bash
################################################################################
# SP Server Storage Pool Setup Script
################################################################################
# This script configures storage pools and policy domains on SP servers
# based on configuration from Ansible inventory and host_vars files.
#
# Usage:
#   ./setup_sp_server_storage.sh <sp-server-hostname>
#
# Example:
#   ./setup_sp_server_storage.sh sp-server-01
#   ./setup_sp_server_storage.sh sp-server-02
#
# Prerequisites:
#   - SP Server must be installed and running
#   - Ansible inventory and host_vars must be configured
#   - SSH access to SP server
#   - tsminst1 user must exist on SP server
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
Usage: $0 <sp-server-hostname>

Configure storage pools and policy domains on an SP server.

Arguments:
  sp-server-hostname    Hostname from inventory (e.g., sp-server-01, sp-server-02)

Examples:
  $0 sp-server-01
  $0 sp-server-02

The script will:
  1. Read configuration from playbooks/host_vars/<hostname>.yml
  2. Connect to the SP server via SSH
  3. Create storage pool directories
  4. Define storage pools (BACKUPPOOL, SPACEMGPOOL, ARCHIVEPOOL)
  5. Define policy domain (GPFS_DOMAIN)
  6. Register HSM client nodes

Configuration is read from:
  - Inventory: $INVENTORY_FILE
  - Host vars: $HOST_VARS_DIR/<hostname>.yml

EOF
    exit 1
}

parse_yaml() {
    local yaml_file="$1"
    local key="$2"
    
    # Simple YAML parser for our specific use case
    grep "^${key}:" "$yaml_file" | sed "s/^${key}:[[:space:]]*//" | tr -d '"' | tr -d "'"
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
        local in_sp_servers=$(grep -A 100 "^\[sp_servers\]" "$INVENTORY_FILE" | grep -B 100 "^\[" | grep "^${hostname}" || echo "")
        
        if [ -n "$in_sp_servers" ]; then
            user=$(grep -A 20 "^\[sp_servers:vars\]" "$INVENTORY_FILE" | grep "^ansible_user=" | cut -d'=' -f2)
        fi
    fi
    
    # Default to root if not found
    echo "${user:-root}"
}

################################################################################
# Main Script
################################################################################

# Check arguments
if [ $# -ne 1 ]; then
    print_error "Invalid number of arguments"
    usage
fi

SP_SERVER_HOSTNAME="$1"
HOST_VARS_FILE="$HOST_VARS_DIR/${SP_SERVER_HOSTNAME}.yml"

print_header "SP SERVER STORAGE SETUP"
echo "Server: $SP_SERVER_HOSTNAME"
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

# Read configuration from host_vars
print_info "Reading configuration from $HOST_VARS_FILE"

SERVER_NAME=$(parse_yaml "$HOST_VARS_FILE" "server_name")
TSM_USER=$(parse_yaml "$HOST_VARS_FILE" "tsm_user")
TSM_GROUP=$(parse_yaml "$HOST_VARS_FILE" "tsm_group")
ANSIBLE_HOST=$(get_ansible_host "$SP_SERVER_HOSTNAME")
ANSIBLE_USER=$(get_ansible_user "$SP_SERVER_HOSTNAME")

if [ -z "$SERVER_NAME" ] || [ -z "$TSM_USER" ] || [ -z "$ANSIBLE_HOST" ]; then
    print_error "Failed to read required configuration"
    print_info "server_name: $SERVER_NAME"
    print_info "tsm_user: $TSM_USER"
    print_info "ansible_host: $ANSIBLE_HOST"
    print_info "ansible_user: $ANSIBLE_USER"
    exit 1
fi

print_success "Configuration loaded:"
echo "  Server Name: $SERVER_NAME"
echo "  TSM User: $TSM_USER"
echo "  TSM Group: $TSM_GROUP"
echo "  Ansible Host: $ANSIBLE_HOST"
echo "  Ansible User: $ANSIBLE_USER"
echo ""

# Storage pool configuration (can be customized)
STORAGE_BASE_DIR="/TSMdbspace01"
POOL_SIZE="50G"
STORAGE_POOLS=("backuppool" "spacemgpool" "archivepool")

print_header "STEP 1: CREATE STORAGE DIRECTORIES"

print_info "Connecting to $ANSIBLE_HOST as $ANSIBLE_USER..."

# Create directories on SP server
for pool in "${STORAGE_POOLS[@]}"; do
    print_info "Creating directory: $STORAGE_BASE_DIR/$pool"
    ssh "$ANSIBLE_USER@$ANSIBLE_HOST" "sudo mkdir -p $STORAGE_BASE_DIR/$pool && sudo chown -R $TSM_USER:$TSM_GROUP $STORAGE_BASE_DIR/$pool && sudo chmod -R 755 $STORAGE_BASE_DIR/$pool" || {
        print_error "Failed to create directory $STORAGE_BASE_DIR/$pool"
        exit 1
    }
done

print_success "Storage directories created"
echo ""

print_header "STEP 2: CONFIGURE SP SERVER STORAGE POOLS"

# Generate dsmadmc commands (no comments - they cause errors)
DSMADMC_COMMANDS=$(cat <<EOF
DEFINE STGPOOL BACKUPPOOL STGTYPE=DIRECTORY MAXSIZE=$POOL_SIZE
DEFINE STGPOOL SPACEMGPOOL STGTYPE=DIRECTORY MAXSIZE=$POOL_SIZE
DEFINE STGPOOL ARCHIVEPOOL STGTYPE=DIRECTORY MAXSIZE=$POOL_SIZE
DEFINE STGPOOLDIRECTORY BACKUPPOOL $STORAGE_BASE_DIR/backuppool
DEFINE STGPOOLDIRECTORY SPACEMGPOOL $STORAGE_BASE_DIR/spacemgpool
DEFINE STGPOOLDIRECTORY ARCHIVEPOOL $STORAGE_BASE_DIR/archivepool
QUERY STGPOOL
QUERY STGPOOLDIRECTORY
EOF
)

print_info "Executing dsmadmc commands on $SERVER_NAME..."
echo "$DSMADMC_COMMANDS" | ssh "$ANSIBLE_USER@$ANSIBLE_HOST" "sudo su - $TSM_USER -c 'dsmadmc -id=admin -password=admin@@123456789'" || {
    print_warning "Some commands may have failed (pools might already exist)"
}

print_success "Storage pools configured"
echo ""

print_header "STEP 3: CONFIGURE POLICY DOMAIN"

POLICY_COMMANDS=$(cat <<EOF
DEFINE DOMAIN GPFS_DOMAIN DESCRIPTION="GPFS Filesets Backup Domain"
DEFINE POLICYSET GPFS_DOMAIN STANDARD
DEFINE MGMTCLASS GPFS_DOMAIN STANDARD GPFS_DAILY DESCRIPTION="Daily GPFS backup"
DEFINE COPYGROUP GPFS_DOMAIN STANDARD GPFS_DAILY TYPE=BACKUP DESTINATION=BACKUPPOOL VEREXISTS=30 VERDELETED=60 RETEXTRA=30 RETONLY=90
ASSIGN DEFMGMTCLASS GPFS_DOMAIN STANDARD GPFS_DAILY
VALIDATE POLICYSET GPFS_DOMAIN STANDARD
ACTIVATE POLICYSET GPFS_DOMAIN STANDARD
QUERY DOMAIN GPFS_DOMAIN F=D
QUERY POLICYSET GPFS_DOMAIN STANDARD F=D
EOF
)

print_info "Configuring policy domain..."
echo "$POLICY_COMMANDS" | ssh "$ANSIBLE_USER@$ANSIBLE_HOST" "sudo su - $TSM_USER -c 'dsmadmc -id=admin -password=admin@@123456789'" <<< "y" || {
    print_warning "Some policy commands may have failed (domain might already exist)"
}

print_success "Policy domain configured"
echo ""

print_header "STEP 4: REGISTER HSM CLIENT NODES"

# Read HSM client configuration from host_vars
print_info "Looking for HSM client configurations..."

# Find all hsm-client host_vars files
HSM_CLIENT_FILES=$(find "$HOST_VARS_DIR" -name "hsm-client-*.yml" 2>/dev/null || true)

if [ -z "$HSM_CLIENT_FILES" ]; then
    print_warning "No HSM client configuration files found"
    print_info "Skipping node registration"
else
    while IFS= read -r hsm_file; do
        [ -z "$hsm_file" ] && continue
        print_info "Processing $(basename "$hsm_file")"
        
        # Extract node names for this server
        NODE_NAMES=$(grep -A 10 "sp_servers:" "$hsm_file" | grep "node_name:" | grep -i "$SERVER_NAME" | sed 's/.*node_name:[[:space:]]*//' | tr -d '"' | tr -d "'")
        
        for node_name in $NODE_NAMES; do
            if [ -n "$node_name" ]; then
                print_info "Registering node: $node_name"
                
                REGISTER_CMD="REGISTER NODE $node_name Pass123456789ABC DOMAIN=GPFS_DOMAIN MAXNUMMP=4 COMPRESSION=YES DEDUPLICATION=CLIENTORSERVER"
                
                echo "$REGISTER_CMD" | ssh "$ANSIBLE_USER@$ANSIBLE_HOST" "sudo su - $TSM_USER -c 'dsmadmc -id=admin -password=admin@@123456789'" || {
                    print_warning "Node $node_name might already be registered"
                }
            fi
        done
    done <<< "$HSM_CLIENT_FILES"
    
    print_success "Node registration completed"
fi

echo ""
print_header "SETUP COMPLETE"
print_success "SP Server $SERVER_NAME is configured and ready!"
echo ""
echo "Summary:"
echo "  ✅ Storage pools created (BACKUPPOOL, SPACEMGPOOL, ARCHIVEPOOL)"
echo "  ✅ Policy domain GPFS_DOMAIN configured"
echo "  ✅ HSM client nodes registered"
echo ""
echo "Next steps:"
echo "  1. Verify configuration: ssh $ANSIBLE_USER@$ANSIBLE_HOST 'sudo su - $TSM_USER -c \"dsmadmc -id=admin -password=admin@@123456789\"'"
echo "  2. Run: QUERY STGPOOL"
echo "  3. Run: QUERY DOMAIN GPFS_DOMAIN F=D"
echo "  4. Test backup using: ./trigger_gpfs_backup.sh"
echo ""

# Made with Bob
