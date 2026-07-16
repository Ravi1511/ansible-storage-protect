# Petascale Cleanup Guide

## Overview

This guide provides comprehensive instructions for cleaning up Petascale IBM Storage Protect configurations to allow fresh testing or reconfiguration.

## Table of Contents

1. [Cleanup Scripts Overview](#cleanup-scripts-overview)
2. [Complete Cleanup (All Components)](#complete-cleanup-all-components)
3. [SP Server Cleanup](#sp-server-cleanup)
4. [HSM Client Cleanup](#hsm-client-cleanup)
5. [BA Client Cleanup](#ba-client-cleanup)
6. [Manual Cleanup Procedures](#manual-cleanup-procedures)
7. [Verification](#verification)
8. [Troubleshooting](#troubleshooting)

---

## Cleanup Scripts Overview

### Available Scripts

| Script | Purpose | Components |
|--------|---------|------------|
| `cleanup_all.sh` | Complete cleanup of all components | SP Servers, HSM Clients, BA Clients |
| `cleanup_hsm_clients.sh` | HSM client cleanup only | HSM Clients |
| `cleanup_ba_clients.sh` | BA client cleanup only | BA Clients |
| `petascale_configure_cleanup.yml` | SP server cleanup playbook | SP Servers |

### Script Locations

```
ansible-ibm-storage-protect-2/
├── scripts/
│   ├── cleanup_all.sh              # Complete cleanup
│   ├── cleanup_hsm_clients.sh      # HSM client cleanup
│   └── cleanup_ba_clients.sh       # BA client cleanup
└── playbooks/
    └── petascale_configure_cleanup.yml  # SP server cleanup
```

---

## Complete Cleanup (All Components)

### Quick Start

```bash
cd ansible-ibm-storage-protect-2/scripts

# Complete cleanup with default settings
./cleanup_all.sh ../playbooks/inventory/petascale.ini
```

### Usage Options

```bash
./cleanup_all.sh [inventory_file] [options]

Options:
  --disable-dmapi    Disable DMAPI on GPFS filesystem
  --remove-testdata  Remove test data from GPFS filesets
  --skip-sp-servers  Skip SP server cleanup
  --skip-hsm-clients Skip HSM client cleanup
  --skip-ba-clients  Skip BA client cleanup
```

### Examples

**1. Complete cleanup with all options:**
```bash
./cleanup_all.sh ../playbooks/inventory/petascale.ini \
  --disable-dmapi \
  --remove-testdata
```

**2. Cleanup only clients (skip SP servers):**
```bash
./cleanup_all.sh ../playbooks/inventory/petascale.ini \
  --skip-sp-servers
```

**3. Cleanup only SP servers:**
```bash
./cleanup_all.sh ../playbooks/inventory/petascale.ini \
  --skip-hsm-clients \
  --skip-ba-clients
```

### What Gets Cleaned

#### SP Servers
- ✅ Stops DB2 and dsmserv processes
- ✅ Drops DB2 instance
- ✅ Removes TSM user and group
- ✅ Removes instance directories
- ✅ Removes configuration files
- ✅ Removes BA client config on SP server

#### HSM Clients
- ✅ Removes HSM from GPFS (`dsmmigfs remove`)
- ✅ Stops TSM processes (dsmc, dsmmigfs, dsmrecall)
- ✅ Removes HSM configuration files
- ✅ Removes BA configuration files (if exists)
- ✅ Removes SSL certificates
- ✅ Removes password files
- ✅ Removes log files
- ✅ Optionally disables DMAPI on GPFS
- ✅ Optionally removes test data

#### BA Clients
- ✅ Stops TSM processes (dsmc, dsmcad)
- ✅ Removes configuration files
- ✅ Removes SSL certificates
- ✅ Removes password files
- ✅ Removes log files

---

## SP Server Cleanup

### Using Ansible Playbook

```bash
cd ansible-ibm-storage-protect-2

# Cleanup all SP servers
ansible-playbook playbooks/petascale_configure_cleanup.yml \
  -i playbooks/inventory/petascale.ini

# Cleanup specific SP server
ansible-playbook playbooks/petascale_configure_cleanup.yml \
  -i playbooks/inventory/petascale.ini \
  --limit sp-server-01
```

### Playbook Options

```bash
# Force mode (default) - kills stubborn processes
ansible-playbook playbooks/petascale_configure_cleanup.yml \
  -i playbooks/inventory/petascale.ini

# Strict mode - fails if processes won't stop
ansible-playbook playbooks/petascale_configure_cleanup.yml \
  -i playbooks/inventory/petascale.ini \
  -e "cleanup_force_mode=false"

# Custom retry configuration
ansible-playbook playbooks/petascale_configure_cleanup.yml \
  -i playbooks/inventory/petascale.ini \
  -e "cleanup_max_retries=5" \
  -e "cleanup_wait_seconds=15"
```

### What Gets Cleaned

```
SP Server Components:
  - DB2 processes and instance
  - dsmserv processes
  - TSM user (tsminst1) and group
  - Instance directories (/home/tsminst1)
  - Configuration files (/opt/tivoli/tsm/server)
  - BA client config on SP server
  - Log files (/var/log/tsm)
```

---

## HSM Client Cleanup

### Using Cleanup Script

```bash
cd ansible-ibm-storage-protect-2/scripts

# Basic HSM client cleanup
./cleanup_hsm_clients.sh ../playbooks/inventory/petascale.ini

# With DMAPI disable
./cleanup_hsm_clients.sh ../playbooks/inventory/petascale.ini \
  --disable-dmapi

# With test data removal
./cleanup_hsm_clients.sh ../playbooks/inventory/petascale.ini \
  --remove-testdata

# Complete cleanup with all options
./cleanup_hsm_clients.sh ../playbooks/inventory/petascale.ini \
  --disable-dmapi \
  --remove-testdata
```

### Cleanup Steps

The script performs the following steps:

1. **Remove HSM from GPFS**
   ```bash
   dsmmigfs remove /gpfs_main
   ```

2. **Stop TSM Processes**
   ```bash
   pkill -9 dsmc
   pkill -9 dsmmigfs
   pkill -9 dsmrecall
   ```

3. **Remove Configuration Files**
   ```
   /opt/tivoli/tsm/client/hsm/bin/dsm.sys
   /opt/tivoli/tsm/client/hsm/bin/dsm.opt
   /opt/tivoli/tsm/client/ba/bin/dsm.sys
   /opt/tivoli/tsm/client/ba/bin/dsm.opt
   ```

4. **Remove Certificates**
   ```
   /opt/tivoli/tsm/client/hsm/bin/dsmcert.*
   /opt/tivoli/tsm/client/ba/bin/dsmcert.*
   ```

5. **Remove Password Files**
   ```
   /opt/tivoli/tsm/client/hsm/bin/TSM.PWD
   /opt/tivoli/tsm/client/ba/bin/TSM.PWD
   ```

6. **Remove Log Files**
   ```
   /var/log/tsm/*
   ```

7. **Disable DMAPI (Optional)**
   ```bash
   mmunmount /gpfs_main
   mmchfs /gpfs_main -z no
   mmmount /gpfs_main
   ```

---

## BA Client Cleanup

### Using Cleanup Script

```bash
cd ansible-ibm-storage-protect-2/scripts

# Basic BA client cleanup
./cleanup_ba_clients.sh ../playbooks/inventory/petascale.ini

# With custom inventory
./cleanup_ba_clients.sh /path/to/custom/inventory.ini
```

### Cleanup Steps

The script performs the following steps:

1. **Stop TSM Processes**
   ```bash
   pkill -9 dsmc
   pkill -9 dsmcad
   ```

2. **Remove Configuration Files**
   ```
   /opt/tivoli/tsm/client/ba/bin/dsm.sys
   /opt/tivoli/tsm/client/ba/bin/dsm.opt
   /opt/tivoli/tsm/client/ba/bin/inclexcl
   ```

3. **Remove Certificates**
   ```
   /opt/tivoli/tsm/client/ba/bin/dsmcert.kdb
   /opt/tivoli/tsm/client/ba/bin/dsmcert.sth
   /opt/tivoli/tsm/client/ba/bin/dsmcert.rdb
   ```

4. **Remove Password Files**
   ```
   /opt/tivoli/tsm/client/ba/bin/TSM.PWD
   /opt/tivoli/tsm/client/ba/bin/spclicert.*
   ```

5. **Remove Log Files**
   ```
   /var/log/tsm/*
   ```

---

## Manual Cleanup Procedures

### SP Server Manual Cleanup

If automated cleanup fails, perform manual cleanup:

```bash
# SSH to SP server
ssh onecloud-user@9.11.53.28
sudo su -

# 1. Stop services
systemctl stop dsmserv
su - tsminst1 -c "db2stop force"

# 2. Drop DB2 instance
/opt/ibm/db2/V11.5/instance/db2idrop tsminst1

# 3. Remove user and group
userdel -r tsminst1
groupdel tsmsrvrs

# 4. Remove directories
rm -rf /home/tsminst1
rm -rf /opt/tivoli/tsm/server
rm -rf /var/log/tsm

# 5. Remove BA client config
rm -f /opt/tivoli/tsm/client/ba/bin/dsm.sys
rm -f /opt/tivoli/tsm/client/ba/bin/dsm.opt
```

### HSM Client Manual Cleanup

```bash
# SSH to HSM client
ssh root@p9d-vm4.storage.tucson.ibm.com

# 1. Remove HSM from GPFS
dsmmigfs remove /gpfs_main

# 2. Stop processes
pkill -9 dsmc
pkill -9 dsmmigfs
pkill -9 dsmrecall

# 3. Remove configuration
rm -rf /opt/tivoli/tsm/client/hsm/bin/dsm.sys
rm -rf /opt/tivoli/tsm/client/hsm/bin/dsm.opt
rm -rf /opt/tivoli/tsm/client/hsm/bin/dsmcert.*
rm -rf /opt/tivoli/tsm/client/hsm/bin/TSM.PWD

# 4. Remove BA client config
rm -rf /opt/tivoli/tsm/client/ba/bin/dsm.sys
rm -rf /opt/tivoli/tsm/client/ba/bin/dsm.opt
rm -rf /opt/tivoli/tsm/client/ba/bin/dsmcert.*
rm -rf /opt/tivoli/tsm/client/ba/bin/TSM.PWD

# 5. Remove logs
rm -rf /var/log/tsm/*

# 6. Disable DMAPI (optional)
mmunmount /gpfs_main
mmchfs /gpfs_main -z no
mmmount /gpfs_main
```

### BA Client Manual Cleanup

```bash
# SSH to BA client
ssh user@ba-client-host

# 1. Stop processes
pkill -9 dsmc
pkill -9 dsmcad

# 2. Remove configuration
rm -f /opt/tivoli/tsm/client/ba/bin/dsm.sys
rm -f /opt/tivoli/tsm/client/ba/bin/dsm.opt
rm -f /opt/tivoli/tsm/client/ba/bin/dsmcert.*
rm -f /opt/tivoli/tsm/client/ba/bin/TSM.PWD

# 3. Remove logs
rm -rf /var/log/tsm/*
```

### Remove Nodes from SP Server

```bash
# SSH to SP server
ssh onecloud-user@9.11.53.28
sudo su - tsminst1

# Connect to SP server
dsmadmc

# Remove nodes
remove node hsm-client-03-sp01
remove node hsm-client-03-sp03
remove node ba-client-01

# Remove policy domains (if needed)
delete policyset GPFS_DOMAIN STANDARD
delete domain GPFS_DOMAIN

# Remove storage pools (if needed)
delete stgpool BACKUPPOOL
delete stgpool SPACEMGPOOL
delete stgpool ARCHIVEPOOL

# Exit
quit
```

---

## Verification

### Verify SP Server Cleanup

```bash
# Check processes
ps aux | grep dsmserv  # Should return nothing
ps aux | grep db2      # Should return nothing

# Check user
id tsminst1  # Should fail

# Check directories
ls -la /home/tsminst1  # Should not exist
ls -la /opt/tivoli/tsm/server  # Should not exist
```

### Verify HSM Client Cleanup

```bash
# Check processes
ps aux | grep dsm  # Should return nothing

# Check configuration
ls -la /opt/tivoli/tsm/client/hsm/bin/dsm.sys  # Should not exist
ls -la /opt/tivoli/tsm/client/ba/bin/dsm.sys   # Should not exist

# Check DMAPI status
mmlsfs /gpfs_main -z  # Should show "No" if disabled

# Check HSM status
dsmmigfs query /gpfs_main  # Should fail or show not configured
```

### Verify BA Client Cleanup

```bash
# Check processes
ps aux | grep dsm  # Should return nothing

# Check configuration
ls -la /opt/tivoli/tsm/client/ba/bin/dsm.sys  # Should not exist

# Check logs
ls -la /var/log/tsm/  # Should be empty or not exist
```

### Automated Verification

All cleanup scripts include built-in verification that runs automatically at the end.

---

## Troubleshooting

### Issue: Processes Won't Stop

**Problem:** TSM processes remain running after cleanup

**Solution:**
```bash
# Force kill all TSM processes
pkill -9 dsm
pkill -9 db2

# Wait and verify
sleep 5
ps aux | grep -E 'dsm|db2'
```

### Issue: DB2 Instance Won't Drop

**Problem:** `db2idrop` fails

**Solution:**
```bash
# Force stop DB2
su - tsminst1 -c "db2stop force"
su - tsminst1 -c "ipclean"

# Try again
/opt/ibm/db2/V11.5/instance/db2idrop tsminst1
```

### Issue: DMAPI Won't Disable

**Problem:** `mmchfs -z no` fails

**Solution:**
```bash
# Ensure HSM is removed first
dsmmigfs remove /gpfs_main

# Force unmount
mmunmount /gpfs_main -f

# Try again
mmchfs /gpfs_main -z no
mmmount /gpfs_main
```

### Issue: Files Won't Delete

**Problem:** Permission denied when removing files

**Solution:**
```bash
# Use sudo or root
sudo rm -rf /opt/tivoli/tsm/client/*/bin/dsm.sys

# Check file attributes
lsattr /path/to/file

# Remove immutable flag if set
chattr -i /path/to/file
```

### Issue: Cleanup Script Fails

**Problem:** Ansible connection errors

**Solution:**
```bash
# Test connectivity
ansible all -i playbooks/inventory/petascale.ini -m ping

# Check SSH keys
ssh-add -l

# Use password authentication
ansible-playbook ... --ask-pass --ask-become-pass
```

---

## Cleanup Order (Recommended)

For best results, follow this cleanup order:

1. **Stop Active Backups**
   - Ensure no backup jobs are running
   - Cancel any scheduled backups

2. **Remove HSM from GPFS**
   - Run `dsmmigfs remove` on HSM clients
   - This prevents GPFS from trying to access TSM

3. **Cleanup Clients**
   - Clean HSM clients first
   - Then clean BA clients

4. **Remove Nodes from SP Server**
   - Use `dsmadmc` to remove node definitions
   - This prevents orphaned node entries

5. **Cleanup SP Servers**
   - Run SP server cleanup last
   - This ensures clients are disconnected first

6. **Verify Everything**
   - Check all components are cleaned
   - Verify no processes running
   - Confirm files removed

---

## Next Steps After Cleanup

After successful cleanup, follow these steps to reconfigure:

1. **Install Components** (if needed)
   ```bash
   ansible-playbook playbooks/petascale_install.yml \
     -i playbooks/inventory/petascale.ini
   ```

2. **Configure Components**
   ```bash
   ansible-playbook playbooks/petascale_configure.yml \
     -i playbooks/inventory/petascale.ini
   ```

3. **Setup SP Server Storage**
   ```bash
   cd scripts
   ./setup_sp_server_storage.sh
   ```

4. **Test Backups**
   ```bash
   ./trigger_gpfs_backup.sh
   ```

5. **Validate Configuration**
   ```bash
   ./validate_petascale_config.sh
   ```

---

## Summary

### Quick Reference

| Task | Command |
|------|---------|
| Complete cleanup | `./cleanup_all.sh ../playbooks/inventory/petascale.ini` |
| SP server only | `ansible-playbook playbooks/petascale_configure_cleanup.yml -i playbooks/inventory/petascale.ini` |
| HSM clients only | `./cleanup_hsm_clients.sh ../playbooks/inventory/petascale.ini` |
| BA clients only | `./cleanup_ba_clients.sh ../playbooks/inventory/petascale.ini` |
| With DMAPI disable | `./cleanup_all.sh ... --disable-dmapi` |
| With test data removal | `./cleanup_all.sh ... --remove-testdata` |

### Files Removed

```
SP Servers:
  /home/tsminst1/*
  /opt/tivoli/tsm/server/*
  /opt/tivoli/tsm/client/ba/bin/dsm.sys
  /var/log/tsm/*

HSM Clients:
  /opt/tivoli/tsm/client/hsm/bin/dsm.sys
  /opt/tivoli/tsm/client/hsm/bin/dsm.opt
  /opt/tivoli/tsm/client/hsm/bin/dsmcert.*
  /opt/tivoli/tsm/client/hsm/bin/TSM.PWD
  /opt/tivoli/tsm/client/ba/bin/dsm.sys
  /opt/tivoli/tsm/client/ba/bin/dsm.opt
  /opt/tivoli/tsm/client/ba/bin/dsmcert.*
  /opt/tivoli/tsm/client/ba/bin/TSM.PWD
  /var/log/tsm/*

BA Clients:
  /opt/tivoli/tsm/client/ba/bin/dsm.sys
  /opt/tivoli/tsm/client/ba/bin/dsm.opt
  /opt/tivoli/tsm/client/ba/bin/dsmcert.*
  /opt/tivoli/tsm/client/ba/bin/TSM.PWD
  /var/log/tsm/*
```

---

## Support

For issues or questions:
- Check the troubleshooting section above
- Review script output for error messages
- Verify inventory file is correct
- Ensure SSH connectivity to all hosts
- Check Ansible version compatibility

---

**Document Version:** 1.0  
**Last Updated:** 2026-06-23  
**Author:** IBM Storage Protect Petascale Team