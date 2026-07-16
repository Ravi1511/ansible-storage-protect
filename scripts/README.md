# Petascale Backup Scripts

This directory contains production-ready scripts for managing IBM Storage Protect Petascale multi-server HSM deployments.

## 📋 Overview

These scripts automate the complete workflow from SP server configuration to GPFS fileset backups, using configuration from Ansible inventory and host_vars files.

## 🎯 Scripts

### 1. `setup_sp_server_storage.sh`
**Purpose:** Configure storage pools and policy domains on SP servers

**Usage:**
```bash
./setup_sp_server_storage.sh <sp-server-hostname>
```

**Examples:**
```bash
./setup_sp_server_storage.sh sp-server-01
./setup_sp_server_storage.sh sp-server-02
```

**What it does:**
- Reads configuration from `playbooks/host_vars/<hostname>.yml`
- Creates storage directories on SP server
- Defines storage pools (BACKUPPOOL, SPACEMGPOOL, ARCHIVEPOOL)
- Configures policy domain (GPFS_DOMAIN)
- Registers HSM client nodes

**Prerequisites:**
- SP Server installed and running
- SSH access to SP server
- Ansible inventory and host_vars configured

---

### 2. `trigger_gpfs_backup.sh`
**Purpose:** Trigger GPFS fileset backups to SP servers

**Usage:**
```bash
./trigger_gpfs_backup.sh <hsm-client-hostname> [fileset-path]
```

**Examples:**
```bash
# Backup all configured filesets
./trigger_gpfs_backup.sh hsm-client-03

# Backup specific fileset
./trigger_gpfs_backup.sh hsm-client-03 /gpfs_main/fileset_2
```

**What it does:**
- Reads fileset-to-server mappings from host_vars
- Connects to HSM client via SSH
- Runs `mmbackup` for each configured fileset
- Verifies backup completion
- Reports success/failure for each backup

**Prerequisites:**
- HSM client configured (petascale_configure.yml completed)
- GPFS running and filesystems mounted
- DMAPI enabled
- SP servers configured with storage pools

---

### 3. `validate_petascale_config.sh`
**Purpose:** Validate configuration before running backups

**Usage:**
```bash
./validate_petascale_config.sh <hsm-client-hostname>
```

**Example:**
```bash
./validate_petascale_config.sh hsm-client-03
```

**What it validates:**
- ✅ Configuration files exist
- ✅ HSM client connectivity
- ✅ GPFS installation and status
- ✅ DMAPI enablement
- ✅ SP server connectivity
- ✅ Storage pool configuration
- ✅ Policy domain configuration
- ✅ HSM client installation

**Output:**
- Detailed validation report
- Pass/Fail/Warning counts
- Actionable recommendations

---

## 🚀 Quick Start Guide

### Step 1: Configure SP Servers

Run this for each SP server in your deployment:

```bash
cd /path/to/ansible-ibm-storage-protect-2/scripts

# Configure PETASCALE-SP01
./setup_sp_server_storage.sh sp-server-01

# Configure PETASCALE-SP03
./setup_sp_server_storage.sh sp-server-02
```

**Expected output:**
```
============================================================
SP SERVER STORAGE SETUP
============================================================
Server: sp-server-01
Date: Mon Jun 23 16:00:00 MST 2026

✅ Configuration files found
✅ Configuration loaded:
  Server Name: PETASCALE-SP01
  TSM User: tsminst1
  TSM Group: tsmusers
  Ansible Host: 9.11.53.28

============================================================
STEP 1: CREATE STORAGE DIRECTORIES
============================================================
✅ Storage directories created

============================================================
STEP 2: CONFIGURE SP SERVER STORAGE POOLS
============================================================
✅ Storage pools configured

============================================================
STEP 3: CONFIGURE POLICY DOMAIN
============================================================
✅ Policy domain configured

============================================================
STEP 4: REGISTER HSM CLIENT NODES
============================================================
✅ Node registration completed

============================================================
SETUP COMPLETE
============================================================
✅ SP Server PETASCALE-SP01 is configured and ready!
```

---

### Step 2: Validate Configuration

Before running backups, validate your setup:

```bash
./validate_petascale_config.sh hsm-client-03
```

**Expected output:**
```
============================================================
VALIDATION SUMMARY
============================================================
Total checks: 25
Passed: 25
Failed: 0
Warnings: 0

✅ All critical checks passed! ✅

Next steps:
  1. Run backups: ./trigger_gpfs_backup.sh hsm-client-03
  2. Monitor backups: Check SP server logs
```

---

### Step 3: Run Backups

Trigger backups for all configured filesets:

```bash
./trigger_gpfs_backup.sh hsm-client-03
```

**Expected output:**
```
============================================================
GPFS FILESET BACKUP
============================================================
HSM Client: hsm-client-03
Date: Mon Jun 23 16:05:00 MST 2026

✅ Configuration files found
✅ HSM Client connection: p9d-vm4.storage.tucson.ibm.com
✅ Found fileset-to-server mappings:
  /gpfs_main/fileset_2 → PETASCALE-SP01
  /gpfs_main/fileset_3 → PETASCALE-SP03

============================================================
BACKUP 1: /gpfs_main/fileset_2 → PETASCALE-SP01
============================================================
ℹ️  Filesystem: /gpfs_main
ℹ️  Fileset: fileset_2
ℹ️  Target Server: PETASCALE-SP01

✅ Fileset exists
ℹ️  Starting backup...
mmbackup: Backup of /gpfs_main/fileset_2 completed successfully
✅ Backup completed successfully!

============================================================
BACKUP SUMMARY
============================================================
Total backups attempted: 2
Successful: 2
Failed: 0

✅ All backups completed successfully! 🎉
```

---

## 📁 Configuration Files

All scripts read configuration from:

### Inventory File
```
playbooks/inventory/petascale.ini
```

Defines:
- SP server hostnames and IP addresses
- HSM client hostnames and IP addresses
- Connection details (SSH keys, users)

### Host Variables
```
playbooks/host_vars/<hostname>.yml
```

**For SP Servers (sp-server-01.yml):**
```yaml
server_name: "PETASCALE-SP01"
tsm_user: "tsminst1"
tsm_group: "tsmusers"
directories:
  - TSMdbspace01
  - TSMdbspace02
```

**For HSM Clients (hsm-client-03.yml):**
```yaml
sp_servers:
  - name: "PETASCALE-SP01"
    address: "9.11.53.28"
    port: "1500"
    node_name: "hsm-client-03-sp01"
    domain: "/gpfs_main/fileset_2"
  - name: "PETASCALE-SP03"
    address: "9.11.53.254"
    port: "1500"
    node_name: "hsm-client-03-sp03"
    domain: "/gpfs_main/fileset_3"

default_server: "PETASCALE-SP01"
```

---

## 🔧 Customization

### Storage Pool Size

Edit `setup_sp_server_storage.sh`:
```bash
POOL_SIZE="50G"  # Change to desired size (e.g., "100G", "500G")
```

### Storage Base Directory

Edit `setup_sp_server_storage.sh`:
```bash
STORAGE_BASE_DIR="/TSMdbspace01"  # Change to your preferred location
```

### Node Password

Edit `setup_sp_server_storage.sh`:
```bash
REGISTER_CMD="REGISTER NODE $node_name Pass123456789ABC ..."
                                      # ^^^^^^^^^^^^^^^^^ Change password
```

---

## 🐛 Troubleshooting

### Issue: "Configuration files not found"

**Solution:**
```bash
# Verify files exist
ls -la playbooks/inventory/petascale.ini
ls -la playbooks/host_vars/hsm-client-03.yml
```

### Issue: "SSH connection failed"

**Solution:**
```bash
# Test SSH manually
ssh root@9.11.53.28

# Check SSH keys
ls -la ~/.ssh/id_rsa
```

### Issue: "Storage pools already exist"

**Solution:**
This is normal if you've run the setup before. The script will show warnings but continue.

### Issue: "GPFS commands not found"

**Solution:**
```bash
# Verify GPFS installation
ssh root@<hsm-client> "/usr/lpp/mmfs/bin/mmlscluster"
```

### Issue: "DMAPI not enabled"

**Solution:**
```bash
# Enable DMAPI
ssh root@<hsm-client> "/usr/lpp/mmfs/bin/mmchfs /gpfs_main -z yes"
```

---

## 📊 Monitoring

### Check Backup Status on SP Server

```bash
ssh root@9.11.53.28
su - tsminst1
dsmadmc -id=admin -password=admin@@123456789

# Check recent backups
QUERY ACTLOG SEARCH="BACKUP" BEGINDATE=TODAY

# Check node status
QUERY NODE <node-name> F=D

# Check storage pool usage
QUERY STGPOOL F=D
```

### Check Active Server Binding

```bash
ssh root@<hsm-client>
/usr/lpp/mmfs/bin/mmlsattr -L /gpfs_main/fileset_2 | grep dmapi.IBMServ
```

---

## 🎯 Best Practices

1. **Always validate before backup:**
   ```bash
   ./validate_petascale_config.sh hsm-client-03
   ```

2. **Test with one fileset first:**
   ```bash
   ./trigger_gpfs_backup.sh hsm-client-03 /gpfs_main/fileset_2
   ```

3. **Monitor storage pool capacity:**
   ```bash
   # On SP server
   dsmadmc "QUERY STGPOOL F=D"
   ```

4. **Schedule regular backups:**
   ```bash
   # Add to crontab
   0 2 * * * /path/to/trigger_gpfs_backup.sh hsm-client-03 >> /var/log/gpfs_backup.log 2>&1
   ```

5. **Keep logs:**
   ```bash
   ./trigger_gpfs_backup.sh hsm-client-03 2>&1 | tee backup_$(date +%Y%m%d_%H%M%S).log
   ```

---

## 📚 Related Documentation

- **Complete Execution Guide:** `../docs/COMPLETE_EXECUTION_GUIDE.md`
- **Backup Test Guide:** `../docs/PETASCALE_BACKUP_TEST_GUIDE.md`
- **SP Server Space Management:** `../docs/SP_SERVER_SPACE_MANAGEMENT.md`
- **Configuration Guide:** `../playbooks/CONFIGURATION_GUIDE.md`

---

## ✅ Success Criteria

Your Petascale deployment is successful when:

- ✅ All validation checks pass
- ✅ Backups complete without errors
- ✅ Storage pools show data
- ✅ Active server binding is set
- ✅ Files can be restored

---

## 🆘 Support

If you encounter issues:

1. Run validation script for detailed diagnostics
2. Check logs in `/var/log/` on HSM client and SP servers
3. Review configuration in host_vars files
4. Consult IBM Storage Protect documentation
5. Check GPFS cluster status

---

## 📝 Notes

- **No Hardcoding:** All scripts read from configuration files
- **Idempotent:** Safe to run multiple times
- **Production-Ready:** Includes error handling and validation
- **Multi-Server:** Supports multiple SP servers and filesets
- **Flexible:** Easy to customize via configuration files

---

**Created:** June 2026  
**Version:** 1.0  
**Status:** Production Ready ✅