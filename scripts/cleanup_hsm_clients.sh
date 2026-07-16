#!/bin/bash
################################################################################
# HSM CLIENT CLEANUP SCRIPT
################################################################################
#
# Purpose: Clean up HSM client configuration to allow fresh testing
#
# What it cleans:
#   - Removes HSM from GPFS filesystem (dsmmigfs remove)
#   - Stops TSM client processes (dsmc, dsmmigfs, dsmrecall)
#   - Removes HSM configuration files (dsm.sys, dsm.opt)
#   - Removes BA client configuration files (if exists)
#   - Removes SSL certificates
#   - Removes password files
#   - Removes log files
#   - Optionally disables DMAPI on GPFS
#
# Usage:
#   ./cleanup_hsm_clients.sh [inventory_file] [options]
#
# Options:
#   --disable-dmapi    Disable DMAPI on GPFS filesystem
#   --remove-testdata  Remove test data from GPFS filesets
#
# Examples:
#   ./cleanup_hsm_clients.sh
#   ./cleanup_hsm_clients.sh ../playbooks/inventory/petascale.ini
#   ./cleanup_hsm_clients.sh ../playbooks/inventory/petascale.ini --disable-dmapi
#   ./cleanup_hsm_clients.sh ../playbooks/inventory/petascale.ini --remove-testdata
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

# Parse options
DISABLE_DMAPI=false
REMOVE_TESTDATA=false

for arg in "$@"; do
    case $arg in
        --disable-dmapi)
            DISABLE_DMAPI=true
            shift
            ;;
        --remove-testdata)
            REMOVE_TESTDATA=true
            shift
            ;;
    esac
done

# Check if inventory file exists
if [ ! -f "$INVENTORY_FILE" ]; then
    echo -e "${RED}ERROR: Inventory file not found: $INVENTORY_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}=========================================="
echo "HSM CLIENT CLEANUP SCRIPT"
echo -e "==========================================${NC}"
echo ""
echo "Inventory: $INVENTORY_FILE"
echo "Disable DMAPI: $DISABLE_DMAPI"
echo "Remove Test Data: $REMOVE_TESTDATA"
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
# STEP 1: Remove HSM from GPFS Filesystem
################################################################################
section_header "STEP 1: Removing HSM from GPFS Filesystem"

echo "Running 'dsmmigfs remove' on all HSM clients..."
ansible hsm_clients -i "$INVENTORY_FILE" -m shell -a "
    echo '=== Removing HSM from GPFS ==='
    if command -v dsmmigfs &> /dev/null; then
        dsmmigfs remove /gpfs_main 2>&1 || echo 'WARNING: dsmmigfs remove failed or already removed'
    else
        echo 'WARNING: dsmmigfs command not found'
    fi
    sleep 2
" -b || warning_msg "Some hosts may have failed to remove HSM"

success_msg "HSM removal from GPFS completed"

################################################################################
# STEP 2: Stop TSM Client Processes
################################################################################
section_header "STEP 2: Stopping TSM Client Processes"

echo "Stopping dsmc, dsmmigfs, and dsmrecall processes..."
ansible hsm_clients -i "$INVENTORY_FILE" -m shell -a "
    echo '=== Stopping TSM processes ==='
    pkill -9 dsmc 2>/dev/null || true
    pkill -9 dsmmigfs 2>/dev/null || true
    pkill -9 dsmrecall 2>/dev/null || true
    pkill -9 dsmcad 2>/dev/null || true
    sleep 2
    
    echo 'Checking for remaining processes:'
    pgrep dsm && echo 'WARNING: TSM processes still running' || echo 'OK: No TSM processes running'
" -b || warning_msg "Some hosts may have failed to stop processes"

success_msg "Process termination completed"

################################################################################
# STEP 3: Remove HSM Client Configuration Files
################################################################################
section_header "STEP 3: Removing HSM Client Configuration Files"

echo "Removing HSM client configuration files..."
ansible hsm_clients -i "$INVENTORY_FILE" -m shell -a "
    echo '=== Removing HSM configuration files ==='
    rm -f /opt/tivoli/tsm/client/hsm/bin/dsm.sys && echo 'Removed: hsm/dsm.sys' || echo 'Not found: hsm/dsm.sys'
    rm -f /opt/tivoli/tsm/client/hsm/bin/dsm.opt && echo 'Removed: hsm/dsm.opt' || echo 'Not found: hsm/dsm.opt'
    rm -f /opt/tivoli/tsm/client/hsm/bin/inclexcl && echo 'Removed: hsm/inclexcl' || echo 'Not found: hsm/inclexcl'
" -b || warning_msg "Some configuration files may not exist"

success_msg "HSM configuration files removed"

################################################################################
# STEP 4: Remove HSM Client SSL Certificates
################################################################################
section_header "STEP 4: Removing HSM Client SSL Certificates"

echo "Removing HSM client SSL certificate files..."
ansible hsm_clients -i "$INVENTORY_FILE" -m shell -a "
    echo '=== Removing HSM certificate files ==='
    rm -f /opt/tivoli/tsm/client/hsm/bin/dsmcert.kdb && echo 'Removed: hsm/dsmcert.kdb' || echo 'Not found: hsm/dsmcert.kdb'
    rm -f /opt/tivoli/tsm/client/hsm/bin/dsmcert.sth && echo 'Removed: hsm/dsmcert.sth' || echo 'Not found: hsm/dsmcert.sth'
    rm -f /opt/tivoli/tsm/client/hsm/bin/dsmcert.rdb && echo 'Removed: hsm/dsmcert.rdb' || echo 'Not found: hsm/dsmcert.rdb'
    rm -f /opt/tivoli/tsm/client/hsm/bin/dsmcert.crl && echo 'Removed: hsm/dsmcert.crl' || echo 'Not found: hsm/dsmcert.crl'
    rm -f /opt/tivoli/tsm/client/hsm/bin/dsmcert.idx && echo 'Removed: hsm/dsmcert.idx' || echo 'Not found: hsm/dsmcert.idx'
" -b || warning_msg "Some certificate files may not exist"

success_msg "HSM SSL certificates removed"

################################################################################
# STEP 5: Remove HSM Client Password Files
################################################################################
section_header "STEP 5: Removing HSM Client Password Files"

echo "Removing HSM client password storage files..."
ansible hsm_clients -i "$INVENTORY_FILE" -m shell -a "
    echo '=== Removing HSM password files ==='
    rm -f /opt/tivoli/tsm/client/hsm/bin/TSM.PWD && echo 'Removed: hsm/TSM.PWD' || echo 'Not found: hsm/TSM.PWD'
    rm -f /opt/tivoli/tsm/client/hsm/bin/spclicert.kdb && echo 'Removed: hsm/spclicert.kdb' || echo 'Not found: hsm/spclicert.kdb'
    rm -f /opt/tivoli/tsm/client/hsm/bin/spclicert.sth && echo 'Removed: hsm/spclicert.sth' || echo 'Not found: hsm/spclicert.sth'
" -b || warning_msg "Some password files may not exist"

success_msg "HSM password files removed"

################################################################################
# STEP 6: Remove BA Client Configuration Files (if exists on HSM client)
################################################################################
section_header "STEP 6: Removing BA Client Configuration Files"

echo "Removing BA client configuration files (if exists on HSM client)..."
ansible hsm_clients -i "$INVENTORY_FILE" -m shell -a "
    echo '=== Removing BA configuration files ==='
    rm -f /opt/tivoli/tsm/client/ba/bin/dsm.sys && echo 'Removed: ba/dsm.sys' || echo 'Not found: ba/dsm.sys'
    rm -f /opt/tivoli/tsm/client/ba/bin/dsm.opt && echo 'Removed: ba/dsm.opt' || echo 'Not found: ba/dsm.opt'
    rm -f /opt/tivoli/tsm/client/ba/bin/inclexcl && echo 'Removed: ba/inclexcl' || echo 'Not found: ba/inclexcl'
    
    echo '=== Removing BA certificate files ==='
    rm -f /opt/tivoli/tsm/client/ba/bin/dsmcert.kdb && echo 'Removed: ba/dsmcert.kdb' || echo 'Not found: ba/dsmcert.kdb'
    rm -f /opt/tivoli/tsm/client/ba/bin/dsmcert.sth && echo 'Removed: ba/dsmcert.sth' || echo 'Not found: ba/dsmcert.sth'
    rm -f /opt/tivoli/tsm/client/ba/bin/dsmcert.rdb && echo 'Removed: ba/dsmcert.rdb' || echo 'Not found: ba/dsmcert.rdb'
    
    echo '=== Removing BA password files ==='
    rm -f /opt/tivoli/tsm/client/ba/bin/TSM.PWD && echo 'Removed: ba/TSM.PWD' || echo 'Not found: ba/TSM.PWD'
" -b || warning_msg "Some BA client files may not exist"

success_msg "BA client files removed"

################################################################################
# STEP 7: Remove Log Files
################################################################################
section_header "STEP 7: Removing Log Files"

echo "Removing TSM log files..."
ansible hsm_clients -i "$INVENTORY_FILE" -m shell -a "
    echo '=== Removing /var/log/tsm directory ==='
    if [ -d /var/log/tsm ]; then
        rm -rf /var/log/tsm/* && echo 'Removed: /var/log/tsm/*' || echo 'Failed to remove logs'
    else
        echo 'Not found: /var/log/tsm'
    fi
" -b || warning_msg "Some log files may not exist"

success_msg "Log files removed"

################################################################################
# STEP 8: Remove Test Data (Optional)
################################################################################
if [ "$REMOVE_TESTDATA" = true ]; then
    section_header "STEP 8: Removing Test Data"
    
    echo "Removing test data from GPFS filesets..."
    ansible hsm_clients -i "$INVENTORY_FILE" -m shell -a "
        echo '=== Removing test data ==='
        rm -rf /gpfs_main/fileset_*/backup_test/* 2>/dev/null && echo 'Removed: backup_test data' || echo 'Not found: backup_test data'
        rm -rf /gpfs_main/fileset_*/test_* 2>/dev/null && echo 'Removed: test_* data' || echo 'Not found: test_* data'
    " -b || warning_msg "Some test data may not exist"
    
    success_msg "Test data removed"
fi

################################################################################
# STEP 9: Disable DMAPI on GPFS (Optional)
################################################################################
if [ "$DISABLE_DMAPI" = true ]; then
    section_header "STEP 9: Disabling DMAPI on GPFS"
    
    warning_msg "This will unmount and remount the GPFS filesystem!"
    echo "Disabling DMAPI on /gpfs_main..."
    
    ansible hsm_clients -i "$INVENTORY_FILE" -m shell -a "
        echo '=== Disabling DMAPI on GPFS ==='
        mmunmount /gpfs_main && echo 'Unmounted: /gpfs_main' || echo 'Failed to unmount'
        mmchfs /gpfs_main -z no && echo 'DMAPI disabled on /gpfs_main' || echo 'Failed to disable DMAPI'
        mmmount /gpfs_main && echo 'Mounted: /gpfs_main' || echo 'Failed to mount'
        
        echo 'Verifying DMAPI status:'
        mmlsfs /gpfs_main -z
    " -b || error_msg "Failed to disable DMAPI"
    
    success_msg "DMAPI disabled on GPFS"
fi

################################################################################
# STEP 10: Verification
################################################################################
section_header "STEP 10: Verification"

echo "Verifying cleanup on all HSM clients..."
ansible hsm_clients -i "$INVENTORY_FILE" -m shell -a "
    echo '=== Verification Report ==='
    echo 'Host: '$(hostname)
    echo ''
    echo 'Running processes:'
    pgrep -a dsm || echo '  No TSM processes running'
    echo ''
    echo 'HSM configuration files:'
    ls -la /opt/tivoli/tsm/client/hsm/bin/dsm.sys 2>/dev/null || echo '  hsm/dsm.sys: NOT FOUND (OK)'
    ls -la /opt/tivoli/tsm/client/hsm/bin/dsm.opt 2>/dev/null || echo '  hsm/dsm.opt: NOT FOUND (OK)'
    echo ''
    echo 'BA configuration files:'
    ls -la /opt/tivoli/tsm/client/ba/bin/dsm.sys 2>/dev/null || echo '  ba/dsm.sys: NOT FOUND (OK)'
    ls -la /opt/tivoli/tsm/client/ba/bin/dsm.opt 2>/dev/null || echo '  ba/dsm.opt: NOT FOUND (OK)'
    echo ''
    echo 'Certificate files:'
    ls -la /opt/tivoli/tsm/client/hsm/bin/dsmcert.kdb 2>/dev/null || echo '  hsm/dsmcert.kdb: NOT FOUND (OK)'
    ls -la /opt/tivoli/tsm/client/ba/bin/dsmcert.kdb 2>/dev/null || echo '  ba/dsmcert.kdb: NOT FOUND (OK)'
    echo ''
    echo 'Password files:'
    ls -la /opt/tivoli/tsm/client/hsm/bin/TSM.PWD 2>/dev/null || echo '  hsm/TSM.PWD: NOT FOUND (OK)'
    ls -la /opt/tivoli/tsm/client/ba/bin/TSM.PWD 2>/dev/null || echo '  ba/TSM.PWD: NOT FOUND (OK)'
    echo ''
    echo 'Log directory:'
    ls -la /var/log/tsm/ 2>/dev/null | head -5 || echo '  /var/log/tsm: EMPTY or NOT FOUND (OK)'
    echo ''
    echo 'GPFS DMAPI status:'
    mmlsfs /gpfs_main -z 2>/dev/null || echo '  Unable to check DMAPI status'
    echo ''
" -b

################################################################################
# COMPLETION
################################################################################
section_header "CLEANUP COMPLETE"

echo ""
success_msg "HSM client cleanup completed successfully!"
echo ""
echo "Next steps:"
echo "  1. Run petascale_configure.yml to reconfigure HSM clients"
echo "  2. Verify DMAPI is enabled: mmlsfs /gpfs_main -z"
echo "  3. Verify HSM is active: dsmmigfs query /gpfs_main"
echo "  4. Test backup: dsmc migrate /gpfs_main/fileset_2/test_file"
echo ""
echo -e "${BLUE}==========================================${NC}"

# Made with Bob
