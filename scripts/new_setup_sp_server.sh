#!/bin/bash
set -euo pipefail

# =========================
# CONFIG
# =========================
#INVENTORY_FILE="./playbooks/inventory/petascale.ini"
#HOST_VARS_DIR="./playbooks/host_vars"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

INVENTORY_FILE="$PROJECT_ROOT/playbooks/inventory/petascale.ini"
HOST_VARS_DIR="$PROJECT_ROOT/playbooks/host_vars"

STORAGE_BASE_DIR="/TSMdbspace01"
POOL_SIZE="50G"

# =========================
# INPUT
# =========================
if [ $# -ne 1 ]; then
  echo "Usage: $0 <sp-server-hostname>"
  exit 1
fi

SP_SERVER_HOSTNAME="$1"
HOST_VARS_FILE="$HOST_VARS_DIR/hsm-client-03.yml"

echo "========================================"
echo "Processing: $SP_SERVER_HOSTNAME"
echo "========================================"

# =========================
# GET SERVER ACCESS DETAILS
# =========================
ANSIBLE_HOST=$(grep "^$SP_SERVER_HOSTNAME" "$INVENTORY_FILE" | awk '{print $2}' | cut -d'=' -f2)
ANSIBLE_USER=$(grep "^$SP_SERVER_HOSTNAME" "$INVENTORY_FILE" | grep -o 'ansible_user=[^ ]*' | cut -d'=' -f2)

ANSIBLE_USER=${ANSIBLE_USER:-root}

if [ -z "$ANSIBLE_HOST" ]; then
  echo "ERROR: Could not find host in inventory"
  exit 1
fi

echo "Connecting to: $ANSIBLE_HOST"

# =========================
# MAP HOSTNAME → SERVER NAME
# =========================
# Extract suffix (01, 03, etc.)
SERVER_SUFFIX=$(echo "$SP_SERVER_HOSTNAME" | grep -o '[0-9]\+$')

SERVER_NAME="PETASCALE-SP${SERVER_SUFFIX}"

echo "Resolved SERVER_NAME = $SERVER_NAME"

# =========================
# EXTRACT NODE FROM YAML
# =========================
NODE_NAME=$(awk -v srv="$SERVER_NAME" '
  $0 ~ "name:" && $0 ~ srv {found=1}
  found && $0 ~ "node_name:" {
    gsub(/.*node_name:[ \t]*/, "")
    gsub(/"/,"")
    print
    exit
  }
' "$HOST_VARS_FILE")

if [ -z "$NODE_NAME" ]; then
  echo "ERROR: Could not find node_name for $SERVER_NAME"
  exit 1
fi

echo "Node for this server: $NODE_NAME"

# =========================
# STEP 1: CREATE STORAGE DIRS
# =========================
echo "Creating storage directories..."

ssh "$ANSIBLE_USER@$ANSIBLE_HOST" "
  sudo mkdir -p $STORAGE_BASE_DIR/{backuppool,spacemgpool,archivepool}
  sudo chown -R tsminst1:tsmgrp $STORAGE_BASE_DIR
"

# =========================
# STEP 2: STORAGE POOLS
# =========================
echo "Configuring storage pools..."

ssh "$ANSIBLE_USER@$ANSIBLE_HOST" "sudo su - tsminst1 -c '
dsmadmc -id=admin -password=admin@@123456789 <<EOF
DEFINE STGPOOL BACKUPPOOL STGTYPE=DIRECTORY MAXSIZE=$POOL_SIZE
DEFINE STGPOOL SPACEMGPOOL STGTYPE=DIRECTORY MAXSIZE=$POOL_SIZE
DEFINE STGPOOL ARCHIVEPOOL STGTYPE=DIRECTORY MAXSIZE=$POOL_SIZE

DEFINE STGPOOLDIRECTORY BACKUPPOOL $STORAGE_BASE_DIR/backuppool
DEFINE STGPOOLDIRECTORY SPACEMGPOOL $STORAGE_BASE_DIR/spacemgpool
DEFINE STGPOOLDIRECTORY ARCHIVEPOOL $STORAGE_BASE_DIR/archivepool

QUERY STGPOOL
QUIT
EOF
'"

# =========================
# STEP 3: POLICY DOMAIN
# =========================
echo "Configuring policy domain..."

ssh "$ANSIBLE_USER@$ANSIBLE_HOST" "sudo su - tsminst1 -c '
dsmadmc -id=admin -password=admin@@123456789 <<EOF
DEFINE DOMAIN GPFS_DOMAIN
DEFINE POLICYSET GPFS_DOMAIN STANDARD
DEFINE MGMTCLASS GPFS_DOMAIN STANDARD GPFS_DAILY

DEFINE COPYGROUP GPFS_DOMAIN STANDARD GPFS_DAILY TYPE=BACKUP DESTINATION=BACKUPPOOL

ASSIGN DEFMGMTCLASS GPFS_DOMAIN STANDARD GPFS_DAILY
VALIDATE POLICYSET GPFS_DOMAIN STANDARD
ACTIVATE POLICYSET GPFS_DOMAIN STANDARD

QUIT
EOF
'"

# =========================
# STEP 4: REGISTER NODE
# =========================
echo "Registering node..."

ssh "$ANSIBLE_USER@$ANSIBLE_HOST" "sudo su - tsminst1 -c '
dsmadmc -id=admin -password=admin@@123456789 <<EOF
REGISTER NODE $NODE_NAME Pass123456789ABC DOMAIN=GPFS_DOMAIN MAXNUMMP=4
QUIT
EOF
'"

# =========================
# DONE
# =========================
echo "========================================"
echo "✅ SUCCESS for $SERVER_NAME"
echo "Node registered: $NODE_NAME"
echo "========================================"

