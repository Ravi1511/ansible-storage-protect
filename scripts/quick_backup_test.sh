#!/bin/bash
################################################################################
# Quick Petascale Backup Test Script
# 
# Simple script to test backup and restore for both SP servers
# Run this on your HSM client (p9d-vm4.storage.tucson.ibm.com)
#
# Usage: ./quick_backup_test.sh
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Petascale Quick Backup Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}✗ Please run as root${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Running as root${NC}"

# Check GPFS
if ! /usr/lpp/mmfs/bin/mmgetstate | grep -q "active"; then
    echo -e "${RED}✗ GPFS is not active${NC}"
    exit 1
fi
echo -e "${GREEN}✓ GPFS is active${NC}"

# Check filesystem
if ! df -h | grep -q "gpfs_main"; then
    echo -e "${RED}✗ GPFS filesystem not mounted${NC}"
    exit 1
fi
echo -e "${GREEN}✓ GPFS filesystem mounted${NC}"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Step 1: Creating Test Files${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Create test files for fileset_2
echo "Creating test files in /gpfs_main/fileset_2..."
mkdir -p /gpfs_main/fileset_2/backup_test
cd /gpfs_main/fileset_2/backup_test

for i in {1..3}; do
    echo "  Creating testfile_sp01_${i}.dat (10MB)..."
    dd if=/dev/urandom of=testfile_sp01_${i}.dat bs=1M count=10 status=none
    md5sum testfile_sp01_${i}.dat > testfile_sp01_${i}.dat.md5
done
echo -e "${GREEN}✓ Created 3 test files in fileset_2${NC}"

# Create test files for fileset_3
echo ""
echo "Creating test files in /gpfs_main/fileset_3..."
mkdir -p /gpfs_main/fileset_3/backup_test
cd /gpfs_main/fileset_3/backup_test

for i in {1..3}; do
    echo "  Creating testfile_sp03_${i}.dat (10MB)..."
    dd if=/dev/urandom of=testfile_sp03_${i}.dat bs=1M count=10 status=none
    md5sum testfile_sp03_${i}.dat > testfile_sp03_${i}.dat.md5
done
echo -e "${GREEN}✓ Created 3 test files in fileset_3${NC}"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Step 2: Backup fileset_2 → PETASCALE-SP01${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo "Running: mmbackup /gpfs_main/fileset_2 --scope inodespace --tsm-servers PETASCALE-SP01 -t full"
echo ""

if /usr/lpp/mmfs/bin/mmbackup /gpfs_main/fileset_2 --scope inodespace --tsm-servers PETASCALE-SP01 -t full; then
    echo ""
    echo -e "${GREEN}✓ Backup completed for fileset_2${NC}"
    
    # Check active server binding
    BINDING=$(/usr/lpp/mmfs/bin/mmlsattr -L /gpfs_main/fileset_2 2>/dev/null | grep "dmapi.IBMServ" | awk '{print $2}')
    if [ -n "$BINDING" ]; then
        echo -e "${GREEN}✓ Active server binding set: ${BINDING}${NC}"
    else
        echo -e "${YELLOW}⚠ Active server binding not set (may need storage space on server)${NC}"
    fi
else
    echo ""
    echo -e "${RED}✗ Backup failed for fileset_2${NC}"
    echo -e "${YELLOW}⚠ Check SP server storage space (see SP_SERVER_SPACE_MANAGEMENT.md)${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Step 3: Backup fileset_3 → PETASCALE-SP03${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo "Running: mmbackup /gpfs_main/fileset_3 --scope inodespace --tsm-servers PETASCALE-SP03 -t full"
echo ""

if /usr/lpp/mmfs/bin/mmbackup /gpfs_main/fileset_3 --scope inodespace --tsm-servers PETASCALE-SP03 -t full; then
    echo ""
    echo -e "${GREEN}✓ Backup completed for fileset_3${NC}"
    
    # Check active server binding
    BINDING=$(/usr/lpp/mmfs/bin/mmlsattr -L /gpfs_main/fileset_3 2>/dev/null | grep "dmapi.IBMServ" | awk '{print $2}')
    if [ -n "$BINDING" ]; then
        echo -e "${GREEN}✓ Active server binding set: ${BINDING}${NC}"
    else
        echo -e "${YELLOW}⚠ Active server binding not set (may need storage space on server)${NC}"
    fi
else
    echo ""
    echo -e "${RED}✗ Backup failed for fileset_3${NC}"
    echo -e "${YELLOW}⚠ Check SP server storage space (see SP_SERVER_SPACE_MANAGEMENT.md)${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Step 4: Test Restore from PETASCALE-SP01${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

cd /gpfs_main/fileset_2/backup_test

# Delete a test file
echo "Deleting testfile_sp01_1.dat to simulate data loss..."
rm -f testfile_sp01_1.dat

# Restore it
echo "Restoring from PETASCALE-SP01..."
if dsmc restore "/gpfs_main/fileset_2/backup_test/testfile_sp01_1.dat" -servername=PETASCALE-SP01 -replace=yes -quiet 2>/dev/null; then
    echo -e "${GREEN}✓ File restored successfully${NC}"
    
    # Verify checksum
    ORIGINAL_MD5=$(cat testfile_sp01_1.dat.md5 | awk '{print $1}')
    RESTORED_MD5=$(md5sum testfile_sp01_1.dat | awk '{print $1}')
    
    if [ "$ORIGINAL_MD5" == "$RESTORED_MD5" ]; then
        echo -e "${GREEN}✓ Checksum verified - file is intact${NC}"
    else
        echo -e "${RED}✗ Checksum mismatch${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Restore test skipped (may need manual password entry)${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Step 5: Test Restore from PETASCALE-SP03${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

cd /gpfs_main/fileset_3/backup_test

# Delete a test file
echo "Deleting testfile_sp03_1.dat to simulate data loss..."
rm -f testfile_sp03_1.dat

# Restore it
echo "Restoring from PETASCALE-SP03..."
if dsmc restore "/gpfs_main/fileset_3/backup_test/testfile_sp03_1.dat" -servername=PETASCALE-SP03 -replace=yes -quiet 2>/dev/null; then
    echo -e "${GREEN}✓ File restored successfully${NC}"
    
    # Verify checksum
    ORIGINAL_MD5=$(cat testfile_sp03_1.dat.md5 | awk '{print $1}')
    RESTORED_MD5=$(md5sum testfile_sp03_1.dat | awk '{print $1}')
    
    if [ "$ORIGINAL_MD5" == "$RESTORED_MD5" ]; then
        echo -e "${GREEN}✓ Checksum verified - file is intact${NC}"
    else
        echo -e "${RED}✗ Checksum mismatch${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Restore test skipped (may need manual password entry)${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo "Test files created:"
echo "  - /gpfs_main/fileset_2/backup_test (3 files, 30MB)"
echo "  - /gpfs_main/fileset_3/backup_test (3 files, 30MB)"
echo ""

echo "Active server bindings:"
BINDING_2=$(/usr/lpp/mmfs/bin/mmlsattr -L /gpfs_main/fileset_2 2>/dev/null | grep "dmapi.IBMServ" | awk '{print $2}')
BINDING_3=$(/usr/lpp/mmfs/bin/mmlsattr -L /gpfs_main/fileset_3 2>/dev/null | grep "dmapi.IBMServ" | awk '{print $2}')

if [ -n "$BINDING_2" ]; then
    echo -e "  - fileset_2: ${GREEN}${BINDING_2}${NC}"
else
    echo -e "  - fileset_2: ${YELLOW}Not set${NC}"
fi

if [ -n "$BINDING_3" ]; then
    echo -e "  - fileset_3: ${GREEN}${BINDING_3}${NC}"
else
    echo -e "  - fileset_3: ${YELLOW}Not set${NC}"
fi

echo ""
echo "To clean up test files, run:"
echo "  rm -rf /gpfs_main/fileset_2/backup_test"
echo "  rm -rf /gpfs_main/fileset_3/backup_test"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Test Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

echo "For detailed testing, see: docs/PETASCALE_BACKUP_TEST_GUIDE.md"
echo "For space management, see: docs/SP_SERVER_SPACE_MANAGEMENT.md"

# Made with Bob
