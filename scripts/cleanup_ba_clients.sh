#!/bin/bash
################################################################################
# BA CLIENT CLEANUP SCRIPT
################################################################################
#
# Purpose: Clean up BA client configuration to allow fresh testing
#
# What it cleans:
#   - Stops TSM client processes (dsmc, dsmcad)
#   - Removes configuration files (dsm.sys, dsm.opt)
#   - Removes SSL certificates
#   - Removes password files
#   - Removes log files
#
# Usage:
#   ./cleanup_ba_clients.sh [inventory_file]
#
# Examples:
#   ./cleanup_ba_clients.sh
#   ./cleanup_ba_clients.sh ../playbooks/inventory/petascale.ini
#
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default inventory file
INVENTORY_FILE="${1:-../playbooks/inventory/petascale.ini}"

# Check if inventory file exists
if [ ! -f "$INVENTORY_FILE" ]; then
    echo -e "${RED}ERROR: Inventory file not found: $INVENTORY_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}=========================================="
echo "BA CLIENT CLEANUP SCRIPT"
echo -e "==========================================${NC}"
echo ""
echo "Inventory: $INVENTORY_FILE"
echo ""

# Function to display section header
section_header() {
    echo ""
    echo -e "${BLUE}=========================================="
    echo "$1"
    echo -e "==========================================${NC}"
}

# Function to display success message
success_msg() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to display warning message
warning_msg() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Function to display error message
error_msg() {
    echo -e "${RED}✗ $1${NC}"
}

################################################################################
# STEP 1: Stop TSM Client Processes
################################################################################
section_header "STEP 1: Stopping TSM Client Processes"

echo "Stopping dsmc and dsmcad processes on all BA clients..."
ansible ba_clients -i "$INVENTORY_FILE" -m shell -a "
    pkill -9 dsmc 2>/dev/null || true
    pkill -9 dsmcad 2>/dev/null || true
    sleep 2
    pgrep dsmc && echo 'WARNING: dsmc still running' || echo 'OK: No dsmc processes'
    pgrep dsmcad && echo 'WARNING: dsmcad still running' || echo 'OK: No dsmcad processes'
" -b || warning_msg "Some hosts may have failed to stop processes"

success_msg "Process termination completed"

################################################################################
# STEP 2: Remove Configuration Files
################################################################################
section_header "STEP 2: Removing Configuration Files"

echo "Removing BA client configuration files..."
ansible ba_clients -i "$INVENTORY_FILE" -m shell -a "
    echo '=== Removing dsm.sys ==='
    rm -f /opt/tivoli/tsm/client/ba/bin/dsm.sys && echo 'Removed: dsm.sys' || echo 'Not found: dsm.sys'
    
    echo '=== Removing dsm.opt ==='
    rm -f /opt/tivoli/tsm/client/ba/bin/dsm.opt && echo 'Removed: dsm.opt' || echo 'Not found: dsm.opt'
    
    echo '=== Removing inclexcl file ==='
    rm -f /opt/tivoli/tsm/client/ba/bin/inclexcl && echo 'Removed: inclexcl' || echo 'Not found: inclexcl'
" -b || warning_msg "Some configuration files may not exist"

success_msg "Configuration files removed"

################################################################################
# STEP 3: Remove SSL Certificates
################################################################################
section_header "STEP 3: Removing SSL Certificates"

echo "Removing SSL certificate files..."
ansible ba_clients -i "$INVENTORY_FILE" -m shell -a "
    echo '=== Removing certificate database ==='
    rm -f /opt/tivoli/tsm/client/ba/bin/dsmcert.kdb && echo 'Removed: dsmcert.kdb' || echo 'Not found: dsmcert.kdb'
    rm -f /opt/tivoli/tsm/client/ba/bin/dsmcert.sth && echo 'Removed: dsmcert.sth' || echo 'Not found: dsmcert.sth'
    rm -f /opt/tivoli/tsm/client/ba/bin/dsmcert.rdb && echo 'Removed: dsmcert.rdb' || echo 'Not found: dsmcert.rdb'
    rm -f /opt/tivoli/tsm/client/ba/bin/dsmcert.crl && echo 'Removed: dsmcert.crl' || echo 'Not found: dsmcert.crl'
    rm -f /opt/tivoli/tsm/client/ba/bin/dsmcert.idx && echo 'Removed: dsmcert.idx' || echo 'Not found: dsmcert.idx'
" -b || warning_msg "Some certificate files may not exist"

success_msg "SSL certificates removed"

################################################################################
# STEP 4: Remove Password Files
################################################################################
section_header "STEP 4: Removing Password Files"

echo "Removing password storage files..."
ansible ba_clients -i "$INVENTORY_FILE" -m shell -a "
    echo '=== Removing TSM.PWD ==='
    rm -f /opt/tivoli/tsm/client/ba/bin/TSM.PWD && echo 'Removed: TSM.PWD' || echo 'Not found: TSM.PWD'
    
    echo '=== Removing spclicert.kdb ==='
    rm -f /opt/tivoli/tsm/client/ba/bin/spclicert.kdb && echo 'Removed: spclicert.kdb' || echo 'Not found: spclicert.kdb'
    rm -f /opt/tivoli/tsm/client/ba/bin/spclicert.sth && echo 'Removed: spclicert.sth' || echo 'Not found: spclicert.sth'
" -b || warning_msg "Some password files may not exist"

success_msg "Password files removed"

################################################################################
# STEP 5: Remove Log Files
################################################################################
section_header "STEP 5: Removing Log Files"

echo "Removing TSM log files..."
ansible ba_clients -i "$INVENTORY_FILE" -m shell -a "
    echo '=== Removing /var/log/tsm directory ==='
    if [ -d /var/log/tsm ]; then
        rm -rf /var/log/tsm/* && echo 'Removed: /var/log/tsm/*' || echo 'Failed to remove logs'
    else
        echo 'Not found: /var/log/tsm'
    fi
" -b || warning_msg "Some log files may not exist"

success_msg "Log files removed"

################################################################################
# STEP 6: Verification
################################################################################
section_header "STEP 6: Verification"

echo "Verifying cleanup on all BA clients..."
ansible ba_clients -i "$INVENTORY_FILE" -m shell -a "
    echo '=== Verification Report ==='
    echo 'Host: '$(hostname)
    echo ''
    echo 'Running processes:'
    pgrep -a dsm || echo '  No TSM processes running'
    echo ''
    echo 'Configuration files:'
    ls -la /opt/tivoli/tsm/client/ba/bin/dsm.sys 2>/dev/null || echo '  dsm.sys: NOT FOUND (OK)'
    ls -la /opt/tivoli/tsm/client/ba/bin/dsm.opt 2>/dev/null || echo '  dsm.opt: NOT FOUND (OK)'
    echo ''
    echo 'Certificate files:'
    ls -la /opt/tivoli/tsm/client/ba/bin/dsmcert.kdb 2>/dev/null || echo '  dsmcert.kdb: NOT FOUND (OK)'
    echo ''
    echo 'Password files:'
    ls -la /opt/tivoli/tsm/client/ba/bin/TSM.PWD 2>/dev/null || echo '  TSM.PWD: NOT FOUND (OK)'
    echo ''
    echo 'Log directory:'
    ls -la /var/log/tsm/ 2>/dev/null | head -5 || echo '  /var/log/tsm: EMPTY or NOT FOUND (OK)'
    echo ''
" -b

################################################################################
# COMPLETION
################################################################################
section_header "CLEANUP COMPLETE"

echo ""
success_msg "BA client cleanup completed successfully!"
echo ""
echo "Next steps:"
echo "  1. Run petascale_configure.yml to reconfigure BA clients"
echo "  2. Verify configuration with: dsmc query session"
echo ""
echo -e "${BLUE}==========================================${NC}"

# Made with Bob
