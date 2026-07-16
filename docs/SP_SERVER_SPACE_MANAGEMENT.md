# SP Server Space Management Guide

## Problem: ANS1311E Server out of data storage space

When you see this error during mmbackup or regular backups, it means the SP Server storage pools are full and cannot accept new data.

---

## 🔍 Quick Diagnosis

### Check Storage Pool Usage

Run these commands on **each SP Server** to check space:

```bash
# SSH to SP Server
ssh root@<sp-server-hostname>

# Switch to TSM instance user
su - tsminst1

# Check all storage pools
dsmadmc -id=admin -password=admin@@123456789 "QUERY STGPOOL"

# Check specific pool
dsmadmc -id=admin -password=admin@@123456789 "QUERY STGPOOL GPFSPOOL"

# Check occupancy details
dsmadmc -id=admin -password=admin@@123456789 "QUERY OCCUPANCY"
```

**Example Output:**
```
Storage Pool Name: GPFSPOOL
Device Class Name: DIRECTORY
Storage Type: DIRECTORY
Estimated Capacity: 100 G
Pct Util: 99.8%    ← PROBLEM: Nearly full!
```

---

## ✅ Solution 1: Delete Old/Inactive Backups (Recommended)

### Step 1: Identify Nodes with Old Backups

```bash
# List all nodes and their last access time
dsmadmc -id=admin -password=admin@@123456789 "QUERY NODE * F=D"

# Find nodes not accessed in 30+ days
dsmadmc -id=admin -password=admin@@123456789 "SELECT NODE_NAME, DAYS_SINCE_LAST_ACCESS FROM NODES WHERE DAYS_SINCE_LAST_ACCESS > 30"
```

### Step 2: Check Node's Backup Data Size

```bash
# Check specific node's data
dsmadmc -id=admin -password=admin@@123456789 "QUERY OCCUPANCY <NODE_NAME>"

# Example:
dsmadmc -id=admin -password=admin@@123456789 "QUERY OCCUPANCY P9D-VM4"
```

### Step 3: Delete Old Node Data (CAREFUL!)

**⚠️ WARNING: This permanently deletes backup data!**

```bash
# Option A: Delete specific filespace
dsmadmc -id=admin -password=admin@@123456789 "DELETE FILESPACE <NODE_NAME> /gpfs_main TYPE=ANY"

# Option B: Remove entire node (if no longer needed)
dsmadmc -id=admin -password=admin@@123456789 "REMOVE NODE <NODE_NAME>"

# Option C: Expire old backups (safer - keeps recent)
dsmadmc -id=admin -password=admin@@123456789 "EXPIRE INVENTORY <NODE_NAME>"
```

### Step 4: Reclaim Space

```bash
# Reclaim deleted space
dsmadmc -id=admin -password=admin@@123456789 "DELETE VOLHISTORY TYPE=ALL TODATE=TODAY"

# For directory storage pools, space is freed immediately
# For file/tape pools, run:
dsmadmc -id=admin -password=admin@@123456789 "RECLAIM STGPOOL GPFSPOOL"
```

---

## ✅ Solution 2: Add More Storage (Production Solution)

### Option A: Extend Existing Storage Pool

```bash
# Add new directory to existing pool
dsmadmc -id=admin -password=admin@@123456789 "DEFINE VOLUME GPFSPOOL /TSMdbspace05/gpfspool02"

# Verify
dsmadmc -id=admin -password=admin@@123456789 "QUERY VOLUME GPFSPOOL"
```

### Option B: Create New Storage Pool

```bash
# Create new directory
mkdir -p /TSMdbspace05/gpfspool_new
chown tsminst1:tsmusers /TSMdbspace05/gpfspool_new
chmod 755 /TSMdbspace05/gpfspool_new

# Define device class
dsmadmc -id=admin -password=admin@@123456789 "DEFINE DEVCLASS DIRCLASS_NEW DEVTYPE=DIRECTORY DIRECTORY=/TSMdbspace05/gpfspool_new MAXCAPACITY=200G"

# Define storage pool
dsmadmc -id=admin -password=admin@@123456789 "DEFINE STGPOOL GPFSPOOL_NEW DIRCLASS_NEW MAXSIZE=100G"

# Define volume
dsmadmc -id=admin -password=admin@@123456789 "DEFINE VOLUME GPFSPOOL_NEW /TSMdbspace05/gpfspool_new/vol001"

# Update copy group to use new pool
dsmadmc -id=admin -password=admin@@123456789 "UPDATE COPYGROUP GPFS_DOMAIN STANDARD GPFS_DAILY DESTINATION=GPFSPOOL_NEW"
```

### Option C: Add Physical Disk (Best for Production)

```bash
# On the server OS level:
# 1. Add new disk/LUN
# 2. Create filesystem
mkfs.ext4 /dev/sdb1
mkdir -p /TSMdbspace05
mount /dev/sdb1 /TSMdbspace05

# 3. Add to /etc/fstab for persistence
echo "/dev/sdb1 /TSMdbspace05 ext4 defaults 0 0" >> /etc/fstab

# 4. Set ownership
chown -R tsminst1:tsmusers /TSMdbspace05
chmod 755 /TSMdbspace05

# 5. Define in TSM (as shown in Option B)
```

---

## ✅ Solution 3: Adjust Retention Policies (Temporary Relief)

### Reduce Retention Periods

```bash
# Check current retention
dsmadmc -id=admin -password=admin@@123456789 "QUERY COPYGROUP GPFS_DOMAIN STANDARD GPFS_DAILY F=D"

# Reduce retention (example: 30 days to 7 days)
dsmadmc -id=admin -password=admin@@123456789 "UPDATE COPYGROUP GPFS_DOMAIN STANDARD GPFS_DAILY VEREXISTS=7 VERDELETED=7 RETEXTRA=7 RETONLY=7"

# Expire old versions immediately
dsmadmc -id=admin -password=admin@@123456789 "EXPIRE INVENTORY"
```

---

## ✅ Solution 4: Enable Deduplication (Long-term Savings)

### Check Deduplication Status

```bash
dsmadmc -id=admin -password=admin@@123456789 "QUERY STGPOOL GPFSPOOL F=D"
```

### Enable Deduplication

```bash
# Enable on storage pool
dsmadmc -id=admin -password=admin@@123456789 "UPDATE STGPOOL GPFSPOOL ENABLEDEDUP=YES"

# Enable on node
dsmadmc -id=admin -password=admin@@123456789 "UPDATE NODE P9D-VM4 DEDUPLICATION=CLIENTORSERVER"

# Check dedup savings
dsmadmc -id=admin -password=admin@@123456789 "QUERY DEDUP"
```

---

## 🚀 Quick Fix Script for Testing

For **testing environments only**, use this script to quickly free up space:

```bash
#!/bin/bash
# SP Server Space Cleanup Script (TEST ONLY!)
# Run on SP Server as tsminst1 user

echo "=== SP Server Space Cleanup ==="

# Check current usage
echo "Current storage pool usage:"
dsmadmc -id=admin -password=admin@@123456789 "QUERY STGPOOL" -comma -dataonly=yes

# Delete old test backups
echo ""
echo "Deleting test node backups..."
for node in $(dsmadmc -id=admin -password=admin@@123456789 "SELECT NODE_NAME FROM NODES WHERE NODE_NAME LIKE 'TEST%'" -comma -dataonly=yes); do
    echo "Removing node: $node"
    dsmadmc -id=admin -password=admin@@123456789 "REMOVE NODE $node"
done

# Expire inventory
echo ""
echo "Expiring old inventory..."
dsmadmc -id=admin -password=admin@@123456789 "EXPIRE INVENTORY"

# Check new usage
echo ""
echo "New storage pool usage:"
dsmadmc -id=admin -password=admin@@123456789 "QUERY STGPOOL" -comma -dataonly=yes

echo ""
echo "=== Cleanup Complete ==="
```

---

## 📊 Monitoring Commands

### Regular Health Checks

```bash
# Storage pool summary
dsmadmc -id=admin -password=admin@@123456789 "QUERY STGPOOL F=D"

# Database usage
dsmadmc -id=admin -password=admin@@123456789 "QUERY DB F=D"

# Active log usage
dsmadmc -id=admin -password=admin@@123456789 "QUERY LOG F=D"

# Node activity
dsmadmc -id=admin -password=admin@@123456789 "QUERY SESSION"

# Recent activities
dsmadmc -id=admin -password=admin@@123456789 "QUERY ACTLOG SEARCH='ANS' BEGIND=-1"
```

---

## 🎯 Recommended Approach for Your Situation

Based on your setup with **sp-server-01** and **sp-server-02**:

### Immediate Action (Choose One):

1. **For Testing**: Delete old test backups using Solution 1
2. **For Production**: Add storage using Solution 2, Option C

### Commands to Run:

```bash
# On sp-server-01 (PETASCALE-SP01)
ssh root@9.11.53.28
su - tsminst1

# Check space
dsmadmc -id=admin -password=admin@@123456789 "QUERY STGPOOL GPFSPOOL"

# If testing, delete old data
dsmadmc -id=admin -password=admin@@123456789 "QUERY NODE * F=D"
dsmadmc -id=admin -password=admin@@123456789 "REMOVE NODE <old-test-node>"

# Repeat for sp-server-02 (PETASCALE-SP02)
ssh root@9.11.53.254
su - tsminst1
# ... same commands ...
```

---

## ⚠️ Important Notes

1. **Always backup before deleting**: Export node data if needed
2. **Test in dev first**: Don't delete production data without approval
3. **Monitor after changes**: Check space usage regularly
4. **Plan for growth**: Add 20-30% buffer for future backups
5. **Document changes**: Keep track of what was deleted/added

---

## 📞 Need Help?

If space issues persist:
1. Check SP Server logs: `/opt/tivoli/tsm/server/bin/dsmserv.log`
2. Review activity log: `QUERY ACTLOG`
3. Contact IBM Support with server details

---

## Next Steps

After freeing up space, proceed with:
1. Run mmbackup commands (see PETASCALE_BACKUP_TEST_GUIDE.md)
2. Verify active server binding
3. Test backup and restore operations