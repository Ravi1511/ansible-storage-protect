#!/bin/bash
################################################################################
# Petascale Configuration Validator
################################################################################
# This script validates the Petascale configuration before running backups.
# It checks HSM client, SP servers, GPFS, and connectivity.
#
# Usage:
#   ./validate_petascale_config.sh <hsm-client-hostname>
#
# Example:
#   ./validate_petascale_config.sh hsm-client-03
#
# Prerequisites:
#   - Ansible inventory and host_vars configured
#   - SSH access to HSM client and SP servers
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

# Validation results
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

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
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    WARNING_CHECKS=$((WARNING_CHECKS + 1))
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

check() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
}

usage() {
    cat << EOF
Usage: $0 <hsm-client-hostname>

Validate Petascale configuration before running backups.

Arguments:
  hsm-client-hostname   Hostname from inventory (e.g., hsm-client-03)

Example:
  $0 hsm-client-03

The script validates:
  1. Configuration files exist
  2. HSM client connectivity
  3. GPFS installation and status
  4. DMAPI enablement
  5. SP server connectivity
  6. Storage pool configuration
  7. Policy domain configuration
  8. Node registration

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
        local in_sp_servers=$(grep -A 100 "^\[sp_servers\]" "$INVENTORY_FILE" | grep -B 100 "^\[" | grep "^${hostname}" || echo "")
        
        if [ -n "$in_hsm_clients" ]; then
            user=$(grep -A 20 "^\[hsm_clients:vars\]" "$INVENTORY_FILE" | grep "^ansible_user=" | cut -d'=' -f2)
        elif [ -n "$in_sp_servers" ]; then
            user=$(grep -A 20 "^\[sp_servers:vars\]" "$INVENTORY_FILE" | grep "^ansible_user=" | cut -d'=' -f2)
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
        # Check if sshpass is installed
        if ! command -v sshpass &> /dev/null; then
            echo "ERROR: sshpass is not installed. Password authentication requires sshpass."
            echo "Install it with: brew install hudochenkov/sshpass/sshpass"
            return 1
        fi
        sshpass -p "$password" ssh -o StrictHostKeyChecking=no "$user@$host" "$command"
    else
        ssh "$user@$host" "$command"
    fi
}

parse_sp_servers() {
    local yaml_file="$1"
    awk '/^sp_servers:/,/^[^ ]/ {print}' "$yaml_file" | grep -E "(name:|address:)" | paste -d' ' - - | sed 's/.*name:[[:space:]]*"\([^"]*\)".* address:[[:space:]]*"\([^"]*\)".*/\1|\2/'
}

################################################################################
# Main Script
################################################################################

if [ $# -ne 1 ]; then
    print_error "Invalid number of arguments"
    usage
fi

HSM_CLIENT_HOSTNAME="$1"
HOST_VARS_FILE="$HOST_VARS_DIR/${HSM_CLIENT_HOSTNAME}.yml"

print_header "PETASCALE CONFIGURATION VALIDATOR"
echo "HSM Client: $HSM_CLIENT_HOSTNAME"
echo "Date: $(date)"
echo ""

################################################################################
# Check 1: Configuration Files
################################################################################
print_header "CHECK 1: CONFIGURATION FILES"
check

if [ -f "$INVENTORY_FILE" ]; then
    print_success "Inventory file exists: $INVENTORY_FILE"
else
    print_error "Inventory file not found: $INVENTORY_FILE"
fi
check

if [ -f "$HOST_VARS_FILE" ]; then
    print_success "Host vars file exists: $HOST_VARS_FILE"
else
    print_error "Host vars file not found: $HOST_VARS_FILE"
fi
echo ""

################################################################################
# Check 2: HSM Client Connectivity
################################################################################
print_header "CHECK 2: HSM CLIENT CONNECTIVITY"

ANSIBLE_HOST=$(get_ansible_host "$HSM_CLIENT_HOSTNAME")
ANSIBLE_USER=$(get_ansible_user "$HSM_CLIENT_HOSTNAME")
ANSIBLE_PASSWORD=$(get_ansible_password "$HSM_CLIENT_HOSTNAME")
check

if [ -z "$ANSIBLE_HOST" ]; then
    print_error "Failed to find ansible_host for $HSM_CLIENT_HOSTNAME"
    echo ""
    exit 1
fi

print_success "Ansible host: $ANSIBLE_HOST"
print_success "Ansible user: $ANSIBLE_USER"
if [ -n "$ANSIBLE_PASSWORD" ]; then
    print_success "Auth method: password"
else
    print_success "Auth method: SSH key"
fi
check

print_info "Testing SSH connection..."
if ssh_cmd "$ANSIBLE_USER" "$ANSIBLE_HOST" "$ANSIBLE_PASSWORD" "echo 'Connection successful'" &>/dev/null; then
    print_success "SSH connection successful"
else
    print_error "SSH connection failed to $ANSIBLE_USER@$ANSIBLE_HOST"
fi
echo ""

################################################################################
# Check 3: GPFS Installation
################################################################################
print_header "CHECK 3: GPFS INSTALLATION"
check

print_info "Checking GPFS commands..."
GPFS_COMMANDS=("mmlsfs" "mmchfs" "mmlsattr" "mmbackup")
for cmd in "${GPFS_COMMANDS[@]}"; do
    check
    if ssh_cmd "$ANSIBLE_USER" "$ANSIBLE_HOST" "$ANSIBLE_PASSWORD" "test -x $GPFS_BIN/$cmd" 2>/dev/null; then
        print_success "GPFS command found: $cmd"
    else
        print_error "GPFS command not found: $cmd"
    fi
done

check
print_info "Checking GPFS cluster status..."
if ssh_cmd "$ANSIBLE_USER" "$ANSIBLE_HOST" "$ANSIBLE_PASSWORD" "sudo $GPFS_BIN/mmlscluster" &>/dev/null; then
    print_success "GPFS cluster is operational"
else
    print_error "GPFS cluster check failed"
fi
echo ""

################################################################################
# Check 4: GPFS Filesystems
################################################################################
print_header "CHECK 4: GPFS FILESYSTEMS"

print_info "Reading fileset configuration..."
MAPPINGS=$(parse_sp_servers "$HOST_VARS_FILE")

if [ -z "$MAPPINGS" ]; then
    check
    print_error "No sp_servers configuration found"
else
    while IFS='|' read -r server_name server_address; do
        # Extract filesets for this server
        FILESETS=$(awk '/^sp_servers:/,/^[^ ]/ {print}' "$HOST_VARS_FILE" | grep "domain:" | sed 's/.*domain:[[:space:]]*"\([^"]*\)".*/\1/')
        
        for fileset in $FILESETS; do
            check
            print_info "Checking fileset: $fileset"
            if ssh_cmd "$ANSIBLE_USER" "$ANSIBLE_HOST" "$ANSIBLE_PASSWORD" "test -d $fileset" 2>/dev/null; then
                print_success "Fileset exists: $fileset"
            else
                print_error "Fileset not found: $fileset"
            fi
        done
    done <<< "$MAPPINGS"
fi
echo ""

################################################################################
# Check 5: DMAPI Status
################################################################################
print_header "CHECK 5: DMAPI STATUS"
check

print_info "Checking DMAPI enablement..."
DMAPI_STATUS=$(ssh_cmd "$ANSIBLE_USER" "$ANSIBLE_HOST" "$ANSIBLE_PASSWORD" "sudo $GPFS_BIN/mmlsfs all -z" 2>/dev/null | grep -i dmapi || echo "")

if echo "$DMAPI_STATUS" | grep -q "Yes"; then
    print_success "DMAPI is enabled"
else
    print_error "DMAPI is not enabled"
    print_info "Enable with: sudo $GPFS_BIN/mmchfs <filesystem> -z yes"
fi
echo ""

################################################################################
# Check 6: SP Server Connectivity
################################################################################
print_header "CHECK 6: SP SERVER CONNECTIVITY"

print_info "Reading SP server configuration..."
SP_SERVERS=$(parse_sp_servers "$HOST_VARS_FILE")

if [ -z "$SP_SERVERS" ]; then
    check
    print_error "No SP servers configured"
else
    while IFS='|' read -r server_name server_address; do
        check
        print_info "Testing connection to $server_name ($server_address)..."
        
        # Test SSH
        if ssh -o ConnectTimeout=5 -o BatchMode=yes root@"$server_address" "echo 'OK'" &>/dev/null; then
            print_success "SSH connection to $server_name successful"
        else
            print_error "SSH connection to $server_name failed"
        fi
        
        # Test TSM port (1500)
        check
        if ssh_cmd "$ANSIBLE_USER" "$ANSIBLE_HOST" "$ANSIBLE_PASSWORD" "timeout 5 bash -c '</dev/tcp/$server_address/1500'" 2>/dev/null; then
            print_success "TSM port 1500 accessible on $server_name"
        else
            print_warning "TSM port 1500 not accessible on $server_name (may need firewall rules)"
        fi
    done <<< "$SP_SERVERS"
fi
echo ""

################################################################################
# Check 7: SP Server Storage Pools
################################################################################
print_header "CHECK 7: SP SERVER STORAGE POOLS"

if [ -n "$SP_SERVERS" ]; then
    while IFS='|' read -r server_name server_address; do
        check
        print_info "Checking storage pools on $server_name..."
        
        # Get SP server hostname from inventory
        SP_HOSTNAME=$(grep "$server_address" "$INVENTORY_FILE" | awk '{print $1}')
        
        if [ -n "$SP_HOSTNAME" ]; then
            SP_HOST_VARS="$HOST_VARS_DIR/${SP_HOSTNAME}.yml"
            if [ -f "$SP_HOST_VARS" ]; then
                TSM_USER=$(grep "^tsm_user:" "$SP_HOST_VARS" | sed 's/.*:[[:space:]]*//' | tr -d '"' | tr -d "'")
                
                # Check storage pools
                POOL_CHECK=$(ssh root@"$server_address" "su - $TSM_USER -c 'dsmadmc -id=admin -password=admin@@123456789 -dataonly=yes \"QUERY STGPOOL\"'" 2>/dev/null || echo "")
                
                if echo "$POOL_CHECK" | grep -q "BACKUPPOOL"; then
                    print_success "Storage pools configured on $server_name"
                else
                    print_error "Storage pools not configured on $server_name"
                    print_info "Run: ./setup_sp_server_storage.sh $SP_HOSTNAME"
                fi
            else
                print_warning "Host vars not found for $SP_HOSTNAME"
            fi
        else
            print_warning "Could not find hostname for $server_address in inventory"
        fi
    done <<< "$SP_SERVERS"
fi
echo ""

################################################################################
# Check 8: HSM Client Configuration
################################################################################
print_header "CHECK 8: HSM CLIENT CONFIGURATION"
check

print_info "Checking HSM client installation..."
if ssh_cmd "$ANSIBLE_USER" "$ANSIBLE_HOST" "$ANSIBLE_PASSWORD" "test -d /opt/tivoli/tsm/client/hsm/bin" 2>/dev/null; then
    print_success "HSM client is installed"
    
    check
    print_info "Checking dsm.sys configuration..."
    if ssh_cmd "$ANSIBLE_USER" "$ANSIBLE_HOST" "$ANSIBLE_PASSWORD" "test -f /opt/tivoli/tsm/client/hsm/bin/dsm.sys" 2>/dev/null; then
        print_success "dsm.sys configuration exists"
    else
        print_error "dsm.sys configuration not found"
    fi
    
    check
    print_info "Checking dsm.opt configuration..."
    if ssh_cmd "$ANSIBLE_USER" "$ANSIBLE_HOST" "$ANSIBLE_PASSWORD" "test -f /opt/tivoli/tsm/client/hsm/bin/dsm.opt" 2>/dev/null; then
        print_success "dsm.opt configuration exists"
    else
        print_error "dsm.opt configuration not found"
    fi
else
    print_error "HSM client is not installed"
fi
echo ""

################################################################################
# Summary
################################################################################
print_header "VALIDATION SUMMARY"
echo "Total checks: $TOTAL_CHECKS"
echo "Passed: $PASSED_CHECKS"
echo "Failed: $FAILED_CHECKS"
echo "Warnings: $WARNING_CHECKS"
echo ""

if [ $FAILED_CHECKS -eq 0 ]; then
    print_success "All critical checks passed! ✅"
    echo ""
    echo "Next steps:"
    echo "  1. Run backups: ./trigger_gpfs_backup.sh $HSM_CLIENT_HOSTNAME"
    echo "  2. Monitor backups: Check SP server logs"
    echo ""
    exit 0
else
    print_error "Some checks failed. Please fix the issues above before running backups."
    echo ""
    echo "Common fixes:"
    echo "  - Configure SP servers: ./setup_sp_server_storage.sh <sp-server-hostname>"
    echo "  - Run HSM client configuration: ansible-playbook playbooks/petascale_configure.yml -i playbooks/inventory/petascale.ini --limit $HSM_CLIENT_HOSTNAME"
    echo "  - Enable DMAPI: ssh $ANSIBLE_USER@$ANSIBLE_HOST 'sudo $GPFS_BIN/mmchfs <filesystem> -z yes'"
    echo ""
    exit 1
fi

# Made with Bob
