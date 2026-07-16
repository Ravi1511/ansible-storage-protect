#!/usr/bin/env bash
set -euo pipefail

# Simple helper to create the required storage pool directory on an already configured SP server.
# Run this on the SP server host.

STGPOOL_DIR="${STGPOOL_DIR:-/tmp/data}"
STGPOOL_OWNER="${STGPOOL_OWNER:-tsminst1}"
STGPOOL_GROUP="${STGPOOL_GROUP:-tsmusers}"
STGPOOL_MODE="${STGPOOL_MODE:-0755}"

echo "============================================================"
echo "SP SERVER STORAGE DIRECTORY PREP"
echo "============================================================"
echo "Directory : $STGPOOL_DIR"
echo "Owner     : $STGPOOL_OWNER"
echo "Group     : $STGPOOL_GROUP"
echo "Mode      : $STGPOOL_MODE"
echo "============================================================"

if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] Run this script as root on the SP server."
  exit 1
fi

mkdir -p "$STGPOOL_DIR"
chown "$STGPOOL_OWNER:$STGPOOL_GROUP" "$STGPOOL_DIR"
chmod "$STGPOOL_MODE" "$STGPOOL_DIR"

echo "[INFO] Directory prepared successfully."
ls -ld "$STGPOOL_DIR"
