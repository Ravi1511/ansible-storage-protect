#!/usr/bin/env bash
set -euo pipefail

# Minimal GPFS policy + node bootstrap for an already configured IBM Storage Protect server.
# Run this from the client host where dsmadmc is installed.
# This script assumes the storage pool directory already exists on the SP server.

SERVER_NAME="${SERVER_NAME:-PETASCALE-SP01}"
ADMIN_ID="${ADMIN_ID:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin@@123456789}"
DSMADMC_BIN="${DSMADMC_BIN:-/opt/tivoli/tsm/client/ba/bin/dsmadmc}"
#NODE_NAME="hsm-client-03-sp03" \
STGPOOL_NAME="${STGPOOL_NAME:-GPFSPOOL}"
STGPOOL_DIR="${STGPOOL_DIR:-/tmp/data}"
STGPOOL_MAXSIZE="${STGPOOL_MAXSIZE:-100G}"
POLICY_DOMAIN="${POLICY_DOMAIN:-GPFS_DOMAIN}"
POLICY_SET="${POLICY_SET:-STANDARD}"
MGMT_CLASS="${MGMT_CLASS:-GPFS_DAILY}"
DOMAIN_DESCRIPTION="${DOMAIN_DESCRIPTION:-GPFS Filesets Backup Domain}"
MGMT_DESCRIPTION="${MGMT_DESCRIPTION:-Daily GPFS backup}"
VEREXISTS="${VEREXISTS:-30}"
VERDELETED="${VERDELETED:-60}"
RETEXTRA="${RETEXTRA:-30}"
RETONLY="${RETONLY:-90}"

NODE_NAME="${NODE_NAME:-hsm-client-03-sp01}"
NODE_PASSWORD="${NODE_PASSWORD:-P9dVm4Password@@123}"
NODE_DOMAIN="${NODE_DOMAIN:-$POLICY_DOMAIN}"
NODE_MAXNUMMP="${NODE_MAXNUMMP:-4}"
NODE_COMPRESSION="${NODE_COMPRESSION:-YES}"
NODE_DEDUPLICATION="${NODE_DEDUPLICATION:-CLIENTORSERVER}"

run_dsmadmc() {
  local cmd="$1"
  "$DSMADMC_BIN" -se="$SERVER_NAME" -id="$ADMIN_ID" -pa="$ADMIN_PASSWORD" $cmd
}

query_exists() {
  local query="$1"
  if run_dsmadmc "$query" >/tmp/gpfs_bootstrap_query.out 2>/tmp/gpfs_bootstrap_query.err; then
    return 0
  fi
  return 1
}

run_define() {
  local description="$1"
  local cmd="$2"
  echo "[INFO] $description"
  run_dsmadmc "$cmd"
}

echo "============================================================"
echo "GPFS POLICY + NODE BOOTSTRAP"
echo "============================================================"
echo "Server Alias        : $SERVER_NAME"
echo "dsmadmc Binary      : $DSMADMC_BIN"
echo "Storage Pool        : $STGPOOL_NAME"
echo "Storage Pool Dir    : $STGPOOL_DIR"
echo "Policy Domain       : $POLICY_DOMAIN"
echo "Policy Set          : $POLICY_SET"
echo "Management Class    : $MGMT_CLASS"
echo "Node Name           : $NODE_NAME"
echo "============================================================"

if [[ ! -x "$DSMADMC_BIN" ]]; then
  echo "[ERROR] dsmadmc binary not found: $DSMADMC_BIN"
  echo "[INFO] Run this script on the client machine where dsmadmc is installed."
  exit 1
fi

if query_exists "q stgpool $STGPOOL_NAME"; then
  echo "[INFO] Storage pool already exists: $STGPOOL_NAME"
else
  run_define "Defining storage pool $STGPOOL_NAME" \
    "define stgpool $STGPOOL_NAME stgtype=directory maxsize=$STGPOOL_MAXSIZE"
fi

if run_dsmadmc "q stgpool $STGPOOL_NAME f=d" | grep -F "$STGPOOL_DIR" >/dev/null 2>&1; then
  echo "[INFO] Storage pool directory already defined: $STGPOOL_DIR"
else
  run_define "Defining storage pool directory $STGPOOL_DIR" \
    "define stgpooldirectory $STGPOOL_NAME $STGPOOL_DIR"
fi

if query_exists "q domain $POLICY_DOMAIN"; then
  echo "[INFO] Policy domain already exists: $POLICY_DOMAIN"
else
  run_define "Defining policy domain $POLICY_DOMAIN" \
    "define domain $POLICY_DOMAIN description=\"$DOMAIN_DESCRIPTION\""
fi

if query_exists "q policyset $POLICY_DOMAIN $POLICY_SET"; then
  echo "[INFO] Policy set already exists: $POLICY_DOMAIN $POLICY_SET"
else
  run_define "Defining policy set $POLICY_SET" \
    "define policyset $POLICY_DOMAIN $POLICY_SET"
fi

if query_exists "q mgmtclass $POLICY_DOMAIN $POLICY_SET $MGMT_CLASS"; then
  echo "[INFO] Management class already exists: $MGMT_CLASS"
else
  run_define "Defining management class $MGMT_CLASS" \
    "define mgmtclass $POLICY_DOMAIN $POLICY_SET $MGMT_CLASS description=\"$MGMT_DESCRIPTION\""
fi

if query_exists "q copygroup $POLICY_DOMAIN $POLICY_SET $MGMT_CLASS type=backup"; then
  echo "[INFO] Backup copygroup already exists for $MGMT_CLASS"
else
  run_define "Defining backup copygroup for $MGMT_CLASS" \
    "define copygroup $POLICY_DOMAIN $POLICY_SET $MGMT_CLASS type=backup destination=$STGPOOL_NAME verexists=$VEREXISTS verdeleted=$VERDELETED retextra=$RETEXTRA retonly=$RETONLY"
fi

echo "[INFO] Assigning default management class"
run_dsmadmc "assign defmgmtclass $POLICY_DOMAIN $POLICY_SET $MGMT_CLASS" || true

echo "[INFO] Validating policy set"
run_dsmadmc "validate policyset $POLICY_DOMAIN $POLICY_SET" || true

echo "[INFO] Activating policy set"
printf 'y\n' | "$DSMADMC_BIN" -se="$SERVER_NAME" -id="$ADMIN_ID" -pa="$ADMIN_PASSWORD" "activate policyset $POLICY_DOMAIN $POLICY_SET" || true

if query_exists "q node $NODE_NAME"; then
  echo "[INFO] Node already exists: $NODE_NAME"
else
  run_define "Registering node $NODE_NAME" \
    "register node $NODE_NAME $NODE_PASSWORD domain=$NODE_DOMAIN maxnummp=$NODE_MAXNUMMP compression=$NODE_COMPRESSION deduplication=$NODE_DEDUPLICATION"
fi

echo "============================================================"
echo "FINAL VERIFICATION"
echo "============================================================"
run_dsmadmc "q stgpool $STGPOOL_NAME" || true
run_dsmadmc "q domain $POLICY_DOMAIN" || true
run_dsmadmc "q node $NODE_NAME" || true

echo "============================================================"
echo "BOOTSTRAP COMPLETE"
echo "============================================================"
