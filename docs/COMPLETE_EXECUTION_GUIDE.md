# Complete Petascale Execution Guide

## 🎯 Overview

This guide provides **clear, step-by-step instructions** to execute the complete Petascale backup and restore testing workflow.

**Your Environment:**
- **HSM Client**: p9d-vm4.storage.tucson.ibm.com (hsm-client-03)
- **GPFS**: /gpfs_main (32GB, currently 48% used)
- **Filesets**: fileset_2, fileset_3
- **SP Servers**: 
  - PETASCALE-SP01 (9.11.53.28) → fileset_2
  - PETASCALE-SP03 (9.11.53.254) → fileset_3

---

## 📋 Before You Start

### Current Status
✅ **Completed:**
- HSM client installed
- Configuration playbook run
- DMAPI enabled
- Firewall configured
- SSL certificates imported
- Multi-server dsm.sys created

⚠️ **Blocking Issue:**
- SP servers showing "ANS1311E Server out of data storage space"
- This prevents mmbackup from completing and setting active server binding

---

## 🚀 Execution Steps

### Step 1: Free Up Space on SP Servers

**Why:** mmbackup cannot complete without available storage space on SP servers.

**Choose one solution:**

#### Option A: Delete Old Test Backups (Quick - For Testing)

```bash
# SSH to PETASCALE-SP01
ssh root@9.11.53.28
su - tsminst1

# Check current usage
dsmadmc -id=admin -password=admin@@123456789 "QUERY STGPOOL"

# List all nodes
dsmadmc -id=admin -password=admin@@123456789 "QUERY NODE * F=D"

# Remove old test nodes (CAREFUL!)
dsmadmc -id=admin -password=admin@@123456789 "REMOVE NODE <old-test-node-name>"

# Verify space freed
dsmadmc -id=admin -password=admin@@123456789 "QUERY STGPOOL"

# Repeat for PETASCALE-SP03
ssh root@9.11.53.254
su - tsminst1
# ... same commands ...
```

#### Option B: Add Storage (Production Solution)

```bash
# On SP server (as root)
ssh root@9.11.53.28

# Add new disk or extend existing
# Example: Add 100GB to storage pool
mkdir -p /TSMdbspace05/gpfspool_new
chown tsminst1:tsmusers /TSMdbspace05/gpfspool_new

# Switch to TSM user
su - tsminst1

# Add volume to storage pool
dsmadmc -id=admin -password=admin@@123456789 \
  "DEFINE VOLUME GPFSPOOL /TSMdbspace05/gpfspool_new/vol001"

# Verify
dsmadmc -id=admin -password=admin@@123456789 "QUERY STGPOOL GPFSPOOL"
```

**📖 Detailed Instructions:** See [SP_SERVER_SPACE_MANAGEMENT.md](SP_SERVER_SPACE_MANAGEMENT.md)

---

### Step 2: Run Quick Backup Test

**On HSM Client (p9d-vm4.storage.tucson.ibm.com):**

```bash
# SSH to HSM client
ssh root@p9d-vm4.storage.tucson.ibm.com

# Navigate to scripts directory
cd /root  # or wherever you cloned the repo

# Make script executable
chmod +x ansible-ibm-storage-protect-2/scripts/quick_backup_test.sh

# Run the test
./ansible-ibm-storage-protect-2/scripts/quick_backup_test.sh
```

**What this script does:**
1. ✅ Checks prerequisites (GPFS, filesystem, DMAPI)
2. 📁 Creates test files in both filesets (3 files × 10MB each)
3. 💾 Runs mmbackup for fileset_2 → PETASCALE-SP01
4. 💾 Runs mmbackup for fileset_3 → PETASCALE-SP03
5. 🔍 Verifies active server binding
6. 🔄 Tests restore from both servers
7. ✓ Verifies file integrity with checksums

**Expected Output:**
```
========================================
Petascale Quick Backup Test
========================================

✓ Running as root
✓ GPFS is active
✓ GPFS filesystem mounted

========================================
Step 1: Creating Test Files
========================================

Creating test files in /gpfs_main/fileset_2...
  Creating testfile_sp01_1.dat (10MB)...
  Creating testfile_sp01_2.dat (10MB)...
  Creating testfile_sp01_3.dat (10MB)...
✓ Created 3 test files in fileset_2

Creating test files in /gpfs_main/fileset_3...
  Creating testfile_sp03_1.dat (10MB)...
  Creating testfile_sp03_2.dat (10MB)...
  Creating testfile_sp03_3.dat (10MB)...
✓ Created 3 test files in fileset_3

========================================
Step 2: Backup fileset_2 → PETASCALE-SP01
========================================

Running: mmbackup /gpfs_main/fileset_2 --scope inodespace --tsm-servers PETASCALE-SP01 -t full

[mmbackup output...]

✓ Backup completed for fileset_2
✓ Active server binding set: PETASCALE-SP01

========================================
Step 3: Backup fileset_3 → PETASCALE-SP03
========================================

Running: mmbackup /gpfs_main/fileset_3 --scope inodespace --tsm-servers PETASCALE-SP03 -t full

[mmbackup output...]

✓ Backup completed for fileset_3
✓ Active server binding set: PETASCALE-SP03

========================================
Step 4: Test Restore from PETASCALE-SP01
========================================

Deleting testfile_sp01_1.dat to simulate data loss...
Restoring from PETASCALE-SP01...
✓ File restored successfully
✓ Checksum verified - file is intact

========================================
Step 5: Test Restore from PETASCALE-SP03
========================================

Deleting testfile_sp03_1.dat to simulate data loss...
Restoring from PETASCALE-SP03...
✓ File restored successfully
✓ Checksum verified - file is intact

========================================
Summary
========================================

Test files created:
  - /gpfs_main/fileset_2/backup_test (3 files, 30MB)
  - /gpfs_main/fileset_3/backup_test (3 files, 30MB)

Active server bindings:
  - fileset_2: PETASCALE-SP01
  - fileset_3: PETASCALE-SP03

========================================
Test Complete!
========================================
```

---

### Step 3: Manual Testing (Optional - For Detailed Verification)

If you want more control or detailed testing, follow the manual steps:

**📖 See:** [PETASCALE_BACKUP_TEST_GUIDE.md](PETASCALE_BACKUP_TEST_GUIDE.md)

This guide provides:
- Detailed command-by-command instructions
- Verification steps after each operation
- Troubleshooting for each step
- Complete restore testing workflow

---

### Step 4: Verify Active Server Binding

**Critical Check:** Ensure each fileset is bound to the correct server.

```bash
# Check fileset_2 binding
/usr/lpp/mmfs/bin/mmlsattr -L /gpfs_main/fileset_2 | grep "dmapi.IBMServ"
# Expected: dmapi.IBMServ: PETASCALE-SP01

# Check fileset_3 binding
/usr/lpp/mmfs/bin/mmlsattr -L /gpfs_main/fileset_3 | grep "dmapi.IBMServ"
# Expected: dmapi.IBMServ: PETASCALE-SP03
```

**If binding is not set:**
- Usually means storage space issue on SP server
- Go back to Step 1 and free up more space
- Re-run mmbackup commands

---

### Step 5: Verify Backups on SP Servers

```bash
# Query backups from PETASCALE-SP01
dsmc query backup "/gpfs_main/fileset_2/backup_test/*" \
  -servername=PETASCALE-SP01 \
  -subdir=yes

# Query backups from PETASCALE-SP03
dsmc query backup "/gpfs_main/fileset_3/backup_test/*" \
  -servername=PETASCALE-SP03 \
  -subdir=yes
```

**Expected:** List of backed up files with dates and sizes

---

### Step 6: Clean Up Test Files

```bash
# Remove test files
rm -rf /gpfs_main/fileset_2/backup_test
rm -rf /gpfs_main/fileset_3/backup_test

# Verify cleanup
ls -la /gpfs_main/fileset_2/
ls -la /gpfs_main/fileset_3/
```

---

## ✅ Success Criteria

Your setup is **production-ready** when:

- [x] SP servers have available storage space
- [x] mmbackup completes without "ANS1311E" errors
- [x] Active server binding is set for both filesets
- [x] Files are backed up to correct servers
- [x] Files can be restored from both servers
- [x] Restored files have correct checksums
- [x] No errors in /var/log/tsm/dsmerror.log

---

## 🐛 Troubleshooting

### Issue: "ANS1311E Server out of data storage space"

**Solution:** See Step 1 above or [SP_SERVER_SPACE_MANAGEMENT.md](SP_SERVER_SPACE_MANAGEMENT.md)

### Issue: Active server binding not set

**Cause:** Storage space issue on SP server (mmbackup didn't complete successfully)

**Solution:**
1. Free up space on SP server
2. Re-run mmbackup command
3. Verify binding is set

### Issue: Script fails with "command not found"

**Check:**
```bash
# Verify GPFS commands are available
which mmgetstate
which mmbackup
which mmlsattr

# If not found, check GPFS installation
rpm -qa | grep gpfs
```

### Issue: "Connection refused" to SP server

**Check:**
```bash
# Test connectivity
ping 9.11.53.28
ping 9.11.53.254

# Check firewall
firewall-cmd --list-ports

# Test dsmc connection
dsmc query session -servername=PETASCALE-SP01
dsmc query session -servername=PETASCALE-SP03
```

---

## 📊 Monitoring and Verification

### Check Backup Logs

```bash
# View recent errors
tail -100 /var/log/tsm/dsmerror.log

# View scheduled backup logs
tail -100 /var/log/tsm/dsmsched.log

# Search for specific errors
grep "ANS" /var/log/tsm/dsmerror.log | tail -50
```

### Check GPFS Status

```bash
# GPFS state
/usr/lpp/mmfs/bin/mmgetstate -a

# Filesystem usage
/usr/lpp/mmfs/bin/mmdf /gpfs_main

# Fileset list
/usr/lpp/mmfs/bin/mmlsfileset /gpfs_main

# DMAPI status
/usr/lpp/mmfs/bin/mmlsfs /gpfs_main -z
```

### Check SP Server Status

```bash
# On SP server (as tsminst1)
dsmadmc -id=admin -password=admin@@123456789 "QUERY SESSION"
dsmadmc -id=admin -password=admin@@123456789 "QUERY STGPOOL"
dsmadmc -id=admin -password=admin@@123456789 "QUERY OCCUPANCY"
dsmadmc -id=admin -password=admin@@123456789 "QUERY NODE P9D-VM4"
```

---

## 📝 Post-Testing Checklist

After successful testing:

- [ ] Document test results
- [ ] Save backup/restore logs
- [ ] Verify active server bindings are persistent
- [ ] Clean up test files
- [ ] Update configuration documentation
- [ ] Schedule regular backups (if not already scheduled)
- [ ] Set up monitoring for storage space
- [ ] Plan for storage capacity growth

---

## 🔗 Related Documentation

1. **[SP_SERVER_SPACE_MANAGEMENT.md](SP_SERVER_SPACE_MANAGEMENT.md)**
   - How to free up space on SP servers
   - Add storage to storage pools
   - Monitor storage usage

2. **[PETASCALE_BACKUP_TEST_GUIDE.md](PETASCALE_BACKUP_TEST_GUIDE.md)**
   - Detailed step-by-step testing
   - Manual command execution
   - Comprehensive verification

3. **[PETASCALE_QUICK_REFERENCE.md](../playbooks/PETASCALE_QUICK_REFERENCE.md)**
   - Quick command reference
   - Common operations
   - Troubleshooting tips

4. **[petascale_configure.yml](../playbooks/petascale_configure.yml)**
   - Configuration playbook
   - Automation details

---

## 💡 Tips for Success

1. **Start with Space Management**: Don't skip Step 1 - storage space is critical
2. **Test One Server at a Time**: Easier to troubleshoot if issues arise
3. **Check Logs Frequently**: Review /var/log/tsm/dsmerror.log after each operation
4. **Verify Checksums**: Always verify file integrity after restore
5. **Keep Test Files Small**: Start with 10MB files, scale up after success
6. **Document Everything**: Save command outputs and results

---

## 🎉 Next Steps After Success

Once all tests pass:

1. **Production Deployment**
   - Apply same configuration to other HSM clients
   - Set up scheduled backups
   - Configure retention policies

2. **Monitoring Setup**
   - Set up alerts for storage space
   - Monitor backup success/failure
   - Track active server bindings

3. **Documentation**
   - Update runbooks
   - Document recovery procedures
   - Train team members

4. **Regular Testing**
   - Schedule quarterly restore tests
   - Verify disaster recovery procedures
   - Update documentation as needed

---

## 📞 Support

If you encounter issues not covered in this guide:

1. Check logs: `/var/log/tsm/dsmerror.log`
2. Review SP server logs: `/opt/tivoli/tsm/server/bin/dsmserv.log`
3. Consult IBM documentation
4. Contact IBM Support with:
   - Error messages
   - Log excerpts
   - Configuration details

---

**Good luck with your testing! 🚀**

Remember: The key to success is ensuring SP servers have adequate storage space before running mmbackup.