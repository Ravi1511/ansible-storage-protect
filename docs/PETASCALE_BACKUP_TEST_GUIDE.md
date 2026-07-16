# Petascale Backup and Restore Test Guide

## 🎯 Quick Start - Your Environment

Based on your current setup:
- **HSM Client**: p9d-vm4.storage.tucson.ibm.com (hsm-client-03)
- **GPFS Filesystem**: /gpfs_main (32GB, 48% used, 17GB available)
- **Filesets**: fileset_2 and fileset_3
- **SP Servers**: 
  - PETASCALE-SP01 (9.11.53.28) → backs up fileset_2
  - PETASCALE-SP03 (9.11.53.254) → backs up fileset_3

---

## 📋 Prerequisites Checklist

Before running backup tests, verify:

```bash
# 1. Check GPFS is active
mmgetstate -a
# Should show: active

# 2. Check filesystem is mounted
df -h | grep gpfs_main
# Should show: gpfs_main mounted on /gpfs_main

# 3. Check DMAPI is enabled
mmlsfs /gpfs_main -z
# Should show: -z yes

# 4. Check filesets exist
ls -la /gpfs_main/
# Should show: fileset_2 and fileset_3 directories

# 5. Check HSM configuration
ls -la /opt/tivoli/tsm/client/hsm/bin/dsm.sys
# Should exist

# 6. Test server connectivity
dsmc query session -servername=PETASCALE-SP01
dsmc query session -servername=PETASCALE-SP03
# Both should connect successfully
```

---

## 🚀 Step-by-Step Backup Test

### Step 1: Create Test Files

```bash
# Create test files in fileset_2 (for PETASCALE-SP01)
mkdir -p /gpfs_main/fileset_2/backup_test
cd /gpfs_main/fileset_2/backup_test

# Create 5 test files (10MB each)
for i in {1..5}; do
    echo "Creating testfile_sp01_${i}.dat..."
    dd if=/dev/urandom of=testfile_sp01_${i}.dat bs=1M count=10
    md5sum testfile_sp01_${i}.dat > testfile_sp01_${i}.dat.md5
done

echo "✓ Created 5 test files in fileset_2"
ls -lh

# Create test files in fileset_3 (for PETASCALE-SP03)
mkdir -p /gpfs_main/fileset_3/backup_test
cd /gpfs_main/fileset_3/backup_test

# Create 5 test files (10MB each)
for i in {1..5}; do
    echo "Creating testfile_sp03_${i}.dat..."
    dd if=/dev/urandom of=testfile_sp03_${i}.dat bs=1M count=10
    md5sum testfile_sp03_${i}.dat > testfile_sp03_${i}.dat.md5
done

echo "✓ Created 5 test files in fileset_3"
ls -lh
```

**Expected Output:**
```
-rw-r--r-- 1 root root 10M Jun 23 14:00 testfile_sp01_1.dat
-rw-r--r-- 1 root root  33 Jun 23 14:00 testfile_sp01_1.dat.md5
...
```

---

### Step 2: Run mmbackup for fileset_2 → PETASCALE-SP01

```bash
# Backup fileset_2 to PETASCALE-SP01
echo "Starting backup of fileset_2 to PETASCALE-SP01..."

/usr/lpp/mmfs/bin/mmbackup /gpfs_main/fileset_2 \
    --scope inodespace \
    --tsm-servers PETASCALE-SP01 \
    -t full

# Check exit code
if [ $? -eq 0 ]; then
    echo "✓ Backup completed successfully"
else
    echo "✗ Backup failed - check logs"
fi
```

**Expected Output:**
```
mmbackup: Backup started for /gpfs_main/fileset_2
mmbackup: Connecting to PETASCALE-SP01...
mmbackup: Backing up files...
mmbackup: Backup completed successfully
mmbackup: Files backed up: 5
mmbackup: Bytes transferred: 52428800
```

**If you see "ANS1311E Server out of data storage space":**
- See [SP_SERVER_SPACE_MANAGEMENT.md](SP_SERVER_SPACE_MANAGEMENT.md) for solutions
- Quick fix: Delete old backups on SP server

---

### Step 3: Verify Active Server Binding (fileset_2)

```bash
# Check if active server binding was set
echo "Checking active server binding for fileset_2..."

/usr/lpp/mmfs/bin/mmlsattr -L /gpfs_main/fileset_2 | grep "dmapi.IBMServ"

# Expected output:
# dmapi.IBMServ: PETASCALE-SP01
```

**What this means:**
- ✅ If you see `PETASCALE-SP01`: Active binding is set correctly
- ⚠️ If empty: Binding not set (usually due to storage space issue on server)
- ❌ If wrong server: Configuration error

---

### Step 4: Run mmbackup for fileset_3 → PETASCALE-SP03

```bash
# Backup fileset_3 to PETASCALE-SP03
echo "Starting backup of fileset_3 to PETASCALE-SP03..."

/usr/lpp/mmfs/bin/mmbackup /gpfs_main/fileset_3 \
    --scope inodespace \
    --tsm-servers PETASCALE-SP03 \
    -t full

# Check exit code
if [ $? -eq 0 ]; then
    echo "✓ Backup completed successfully"
else
    echo "✗ Backup failed - check logs"
fi
```

---

### Step 5: Verify Active Server Binding (fileset_3)

```bash
# Check if active server binding was set
echo "Checking active server binding for fileset_3..."

/usr/lpp/mmfs/bin/mmlsattr -L /gpfs_main/fileset_3 | grep "dmapi.IBMServ"

# Expected output:
# dmapi.IBMServ: PETASCALE-SP03
```

---

### Step 6: Verify Backups on SP Servers

```bash
# Query backed up files from PETASCALE-SP01
echo "Querying backups from PETASCALE-SP01..."
dsmc query backup "/gpfs_main/fileset_2/backup_test/*" -servername=PETASCALE-SP01

# Query backed up files from PETASCALE-SP03
echo "Querying backups from PETASCALE-SP03..."
dsmc query backup "/gpfs_main/fileset_3/backup_test/*" -servername=PETASCALE-SP03
```

**Expected Output:**
```
Size    Backup Date         Mgmt Class  A/I File
----    -----------         ----------  --- ----
10.0 MB 06/23/2026 14:05:00 GPFS_DAILY  A   /gpfs_main/fileset_2/backup_test/testfile_sp01_1.dat
...
```

---

## 🔄 Step-by-Step Restore Test

### Step 7: Test Restore from PETASCALE-SP01

```bash
# Create restore directory
mkdir -p /gpfs_main/fileset_2/restore_test
cd /gpfs_main/fileset_2/backup_test

# Delete one test file to simulate data loss
echo "Simulating data loss..."
rm -f testfile_sp01_1.dat
ls -lh testfile_sp01_1.dat  # Should show: No such file or directory

# Restore the file from PETASCALE-SP01
echo "Restoring file from PETASCALE-SP01..."
dsmc restore "/gpfs_main/fileset_2/backup_test/testfile_sp01_1.dat" \
    -servername=PETASCALE-SP01 \
    -replace=yes

# Verify restored file
if [ -f "testfile_sp01_1.dat" ]; then
    echo "✓ File restored successfully"
    
    # Verify checksum
    ORIGINAL_MD5=$(cat testfile_sp01_1.dat.md5 | awk '{print $1}')
    RESTORED_MD5=$(md5sum testfile_sp01_1.dat | awk '{print $1}')
    
    if [ "$ORIGINAL_MD5" == "$RESTORED_MD5" ]; then
        echo "✓ Checksum verified - file is intact"
    else
        echo "✗ Checksum mismatch - file may be corrupted"
    fi
else
    echo "✗ File restore failed"
fi
```

---

### Step 8: Test Restore from PETASCALE-SP03

```bash
# Create restore directory
mkdir -p /gpfs_main/fileset_3/restore_test
cd /gpfs_main/fileset_3/backup_test

# Delete one test file to simulate data loss
echo "Simulating data loss..."
rm -f testfile_sp03_1.dat
ls -lh testfile_sp03_1.dat  # Should show: No such file or directory

# Restore the file from PETASCALE-SP03
echo "Restoring file from PETASCALE-SP03..."
dsmc restore "/gpfs_main/fileset_3/backup_test/testfile_sp03_1.dat" \
    -servername=PETASCALE-SP03 \
    -replace=yes

# Verify restored file
if [ -f "testfile_sp03_1.dat" ]; then
    echo "✓ File restored successfully"
    
    # Verify checksum
    ORIGINAL_MD5=$(cat testfile_sp03_1.dat.md5 | awk '{print $1}')
    RESTORED_MD5=$(md5sum testfile_sp03_1.dat | awk '{print $1}')
    
    if [ "$ORIGINAL_MD5" == "$RESTORED_MD5" ]; then
        echo "✓ Checksum verified - file is intact"
    else
        echo "✗ Checksum mismatch - file may be corrupted"
    fi
else
    echo "✗ File restore failed"
fi
```

---

## 🧹 Cleanup Test Files

```bash
# Remove test files and directories
echo "Cleaning up test files..."

rm -rf /gpfs_main/fileset_2/backup_test
rm -rf /gpfs_main/fileset_2/restore_test
rm -rf /gpfs_main/fileset_3/backup_test
rm -rf /gpfs_main/fileset_3/restore_test

echo "✓ Cleanup complete"
```

---

## 📊 Verification Commands

### Check Backup Status

```bash
# Check mmbackup logs
tail -100 /var/log/tsm/dsmerror.log

# Check active server bindings
/usr/lpp/mmfs/bin/mmlsattr -L /gpfs_main/fileset_2 | grep "dmapi.IBMServ"
/usr/lpp/mmfs/bin/mmlsattr -L /gpfs_main/fileset_3 | grep "dmapi.IBMServ"

# Check GPFS filesystem usage
/usr/lpp/mmfs/bin/mmdf /gpfs_main

# List all backed up files
dsmc query backup "/gpfs_main/fileset_2/*" -servername=PETASCALE-SP01 -subdir=yes
dsmc query backup "/gpfs_main/fileset_3/*" -servername=PETASCALE-SP03 -subdir=yes
```

### Check SP Server Status

```bash
# On SP Server (run as tsminst1)
dsmadmc -id=admin -password=admin@@123456789 "QUERY SESSION"
dsmadmc -id=admin -password=admin@@123456789 "QUERY STGPOOL"
dsmadmc -id=admin -password=admin@@123456789 "QUERY OCCUPANCY"
dsmadmc -id=admin -password=admin@@123456789 "QUERY ACTLOG SEARCH='ANS' BEGIND=-1"
```

---

## 🎯 Success Criteria

Your Petascale configuration is working correctly if:

✅ **Backup Tests Pass:**
- [ ] mmbackup completes without errors for both filesets
- [ ] Active server binding is set correctly (fileset_2 → SP01, fileset_3 → SP03)
- [ ] Files are visible in backup queries on correct servers
- [ ] No "ANS1311E" storage space errors

✅ **Restore Tests Pass:**
- [ ] Files can be restored from both servers
- [ ] Restored files have correct checksums
- [ ] Restore completes without errors

✅ **Configuration Verified:**
- [ ] DMAPI is enabled on GPFS filesystem
- [ ] Multi-server dsm.sys configuration is correct
- [ ] SSL certificates imported for both servers
- [ ] Firewall allows connections to both servers

---

## 🐛 Troubleshooting

### Issue: "ANS1311E Server out of data storage space"

**Solution:** See [SP_SERVER_SPACE_MANAGEMENT.md](SP_SERVER_SPACE_MANAGEMENT.md)

Quick fix:
```bash
# On SP Server
ssh root@9.11.53.28  # or 9.11.53.254
su - tsminst1
dsmadmc -id=admin -password=admin@@123456789 "QUERY STGPOOL"
# Delete old backups or add storage
```

### Issue: Active server binding not set

**Cause:** Usually due to storage space issue on SP server

**Solution:**
1. Free up space on SP server
2. Re-run mmbackup command
3. Verify binding is set

### Issue: "Connection refused" or "Cannot connect to server"

**Check:**
```bash
# Test connectivity
ping 9.11.53.28
ping 9.11.53.254

# Check firewall
firewall-cmd --list-ports

# Check SSL certificates
ls -la /opt/tivoli/tsm/client/ba/bin/dsmcert.kdb
```

### Issue: Files not found in backup query

**Check:**
```bash
# Verify correct server name
dsmc query session -servername=PETASCALE-SP01

# Check dsm.sys configuration
cat /opt/tivoli/tsm/client/hsm/bin/dsm.sys

# Check backup logs
tail -100 /var/log/tsm/dsmerror.log
```

---

## 📝 Next Steps After Successful Testing

1. **Document Results**: Save test output and verification results
2. **Schedule Regular Backups**: Set up cron jobs or TSM schedules
3. **Monitor Storage**: Regularly check SP server storage usage
4. **Test Disaster Recovery**: Perform full restore test periodically
5. **Update Documentation**: Keep configuration docs current

---

## 🔗 Related Documentation

- [SP_SERVER_SPACE_MANAGEMENT.md](SP_SERVER_SPACE_MANAGEMENT.md) - How to free up space on SP servers
- [PETASCALE_QUICK_REFERENCE.md](../playbooks/PETASCALE_QUICK_REFERENCE.md) - Quick command reference
- [petascale_configure.yml](../playbooks/petascale_configure.yml) - Configuration playbook

---

## 💡 Tips

1. **Start Small**: Test with small files first (10MB), then scale up
2. **One Server at a Time**: Test PETASCALE-SP01 first, then SP03
3. **Check Logs**: Always review /var/log/tsm/dsmerror.log after operations
4. **Verify Checksums**: Always verify file integrity after restore
5. **Keep Test Files**: Don't delete test files until restore is verified

---

## ✅ Test Completion Checklist

- [ ] Prerequisites verified
- [ ] Test files created in both filesets
- [ ] mmbackup completed for fileset_2 → PETASCALE-SP01
- [ ] mmbackup completed for fileset_3 → PETASCALE-SP03
- [ ] Active server binding verified for both filesets
- [ ] Backup queries successful on both servers
- [ ] Restore test passed for PETASCALE-SP01
- [ ] Restore test passed for PETASCALE-SP03
- [ ] Checksums verified for restored files
- [ ] Test files cleaned up
- [ ] Results documented

**Once all items are checked, your Petascale configuration is production-ready!** 🎉