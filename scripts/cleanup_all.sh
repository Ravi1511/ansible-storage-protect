#!/bin/bash
################################################################################
# COMPLETE PETASCALE CLEANUP SCRIPT
################################################################################
#
# Purpose: Clean up all Petascale components to allow fresh testing
#
# What it cleans:
#   - SP Servers: DB2, dsmserv, configuration, storage
#   - HSM Clients: HSM from GPFS, configuration, certificates
#   - BA Clients: Configuration, certificates, logs
#
# Usage:
#   ./cleanup_all.sh [inventory_file] [options]
#
# Options:
#   --disable-dmapi    Disable DMAPI on GPFS filesystem
#   --remove-testdata  Remove test data from GPFS filesets
#   --skip-sp-servers  Skip SP server cleanup
#   --skip-hsm-clients Skip HSM client cleanup
#   --skip-ba-clients  Skip BA client cleanup
#
# Examples:
#   ./cleanup_all.sh
#   ./cleanup_all.sh ../playbooks/inventory/petascale.ini
#   ./cleanup_all.sh ../playbooks/inventory/petascale.ini --disable-dmapi
#   ./cleanup_all.sh ../playbooks/inventory/petascale.ini --skip-sp-servers
#
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Default inventory file
INVENTORY_FILE="${1:-../playbooks/inventory/petascale.ini}"

# Parse options
DISABLE_DMAPI=false
REMOVE_TESTDATA=false
SKIP_SP_SERVERS=false
SKIP_HSM_CLIENTS=false
SKIP_BA_CLIENTS=false

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
        --skip-sp-servers)
            SKIP_SP_SERVERS=true
            shift
            ;;
        --skip-hsm-clients)
            SKIP_HSM_CLIENTS=true
            shift
            ;;
        --skip-ba-clients)
            SKIP_BA_CLIENTS=true
            shift
            ;;
    esac
done

# Check if inventory file exists
if [ ! -f "$INVENTORY_FILE" ]; then
    echo -e "${RED}ERROR: Inventory file not found: $INVENTORY_FILE${NC}"
    exit 1
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to display section header
section_header() {
    echo ""
    echo -e "${CYAN}=========================================="
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

# Function to display info message
info_msg() {
    echo -e "${BLUE}ℹ $1${NC}"
}

################################################################################
# BANNER
################################################################################
clear
echo -e "${MAGENTA}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║                    PETASCALE COMPLETE CLEANUP SCRIPT                         ║
║                                                                              ║
║              Clean up all components for fresh testing                       ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
info_msg "Configuration:"
echo "  Inventory File: $INVENTORY_FILE"
echo "  Disable DMAPI: $DISABLE_DMAPI"
echo "  Remove Test Data: $REMOVE_TESTDATA"
echo "  Skip SP Servers: $SKIP_SP_SERVERS"
echo "  Skip HSM Clients: $SKIP_HSM_CLIENTS"
echo "  Skip BA Clients: $SKIP_BA_CLIENTS"
echo ""

# Confirmation prompt
read -p "$(echo -e ${YELLOW}WARNING: This will clean up all Petascale components. Continue? [y/N]: ${NC})" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

# Start time
START_TIME=$(date +%s)
START_TIME_HUMAN=$(date)

################################################################################
# STEP 1: Cleanup SP Servers
################################################################################
if [ "$SKIP_SP_SERVERS" = false ]; then
    section_header "STEP 1: Cleaning up SP Servers"
    
    info_msg "Running SP Server cleanup playbook..."
    
    if ansible-playbook ../playbooks/petascale_configure_cleanup.yml \
        -i "$INVENTORY_FILE"; then
        success_msg "SP Server cleanup completed"
    else
        error_msg "SP Server cleanup failed"
        exit 1
    fi
else
    section_header "STEP 1: Skipping SP Server Cleanup"
    warning_msg "SP Server cleanup skipped as requested"
fi

################################################################################
# STEP 2: Cleanup HSM Clients
################################################################################
if [ "$SKIP_HSM_CLIENTS" = false ]; then
    section_header "STEP 2: Cleaning up HSM Clients"
    
    info_msg "Running HSM Client cleanup script..."
    
    HSM_CLEANUP_CMD=("$SCRIPT_DIR/cleanup_hsm_clients.sh" "$INVENTORY_FILE")
    
    if [ "$DISABLE_DMAPI" = true ]; then
        HSM_CLEANUP_CMD+=("--disable-dmapi")
    fi
    
    if [ "$REMOVE_TESTDATA" = true ]; then
        HSM_CLEANUP_CMD+=("--remove-testdata")
    fi
    
    if bash "${HSM_CLEANUP_CMD[@]}"; then
        success_msg "HSM Client cleanup completed"
    else
        error_msg "HSM Client cleanup failed"
        exit 1
    fi
else
    section_header "STEP 2: Skipping HSM Client Cleanup"
    warning_msg "HSM Client cleanup skipped as requested"
fi

################################################################################
# STEP 3: Cleanup BA Clients
################################################################################
if [ "$SKIP_BA_CLIENTS" = false ]; then
    section_header "STEP 3: Cleaning up BA Clients"
    
    info_msg "Running BA Client cleanup script..."
    
    if bash "$SCRIPT_DIR/cleanup_ba_clients.sh" "$INVENTORY_FILE"; then
        success_msg "BA Client cleanup completed"
    else
        error_msg "BA Client cleanup failed"
        exit 1
    fi
else
    section_header "STEP 3: Skipping BA Client Cleanup"
    warning_msg "BA Client cleanup skipped as requested"
fi

################################################################################
# STEP 4: Final Verification
################################################################################
section_header "STEP 4: Final Verification"

info_msg "Verifying cleanup across all components..."

echo ""
echo "Checking SP Servers..."
ansible sp_servers -i "$INVENTORY_FILE" -m shell -a "
    echo 'Host: '$(hostname)
    pgrep dsmserv && echo '  WARNING: dsmserv still running' || echo '  OK: No dsmserv process'
    pgrep db2 && echo '  WARNING: DB2 still running' || echo '  OK: No DB2 processes'
" -b 2>/dev/null || true

echo ""
echo "Checking HSM Clients..."
ansible hsm_clients -i "$INVENTORY_FILE" -m shell -a "
    echo 'Host: '$(hostname)
    pgrep dsm && echo '  WARNING: TSM processes still running' || echo '  OK: No TSM processes'
    ls /opt/tivoli/tsm/client/hsm/bin/dsm.sys 2>/dev/null && echo '  WARNING: HSM config exists' || echo '  OK: No HSM config'
" -b 2>/dev/null || true

echo ""
echo "Checking BA Clients..."
ansible ba_clients -i "$INVENTORY_FILE" -m shell -a "
    echo 'Host: '$(hostname)
    pgrep dsm && echo '  WARNING: TSM processes still running' || echo '  OK: No TSM processes'
    ls /opt/tivoli/tsm/client/ba/bin/dsm.sys 2>/dev/null && echo '  WARNING: BA config exists' || echo '  OK: No BA config'
" -b 2>/dev/null || true

################################################################################
# COMPLETION
################################################################################
section_header "CLEANUP COMPLETE"

# End time
END_TIME=$(date +%s)
END_TIME_HUMAN=$(date)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
success_msg "Complete Petascale cleanup finished successfully!"
echo ""
echo "Started At : ${START_TIME_HUMAN}"
echo "Finished At: ${END_TIME_HUMAN}"
echo "Duration   : ${MINUTES}m ${SECONDS}s (${DURATION} seconds)"
echo ""
echo -e "${CYAN}Next Steps:${NC}"
echo "  1. Run petascale_install.yml to install components"
echo "  2. Run petascale_configure.yml to configure components"
echo "  3. Run setup_sp_server_storage.sh to configure SP server storage"
echo "  4. Run trigger_gpfs_backup.sh to test backups"
echo "  5. Run validate_petascale_config.sh to verify configuration"
echo ""
echo -e "${BLUE}==========================================${NC}"

# Made with Bob
