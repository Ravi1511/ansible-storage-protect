# GPFS Backup Plan - IBM Storage Protect

## Overview

This document provides a comprehensive plan for backing up GPFS filesets using IBM Storage Protect (Spectrum Protect) with traditional file-level backup approach.

### Current Environment

**GPFS Node (HSM Client)**
- **Hostname**: `p9d-vm4.storage.tucson.ibm.com` (hsm-client-03)
- **IP Address**: To be determined
- **User**: root
- **GPFS Filesystem**: `gpfs_main` mounted at `/gpfs_main`
- **Total Capacity**: 32 GB (32,768 MB across 5 NSDs)

**GPFS Filesets to Backup**
```
Name          Status    Path                      
root          Linked    /gpfs_main                
testfs        Linked    /gpfs_main/testfs         
fileset_1     Linked    /gpfs_main/fileset_1      
fileset_2     Linked    /gpfs_main/fileset_2      
fileset_3     Linked    /gpfs_main/fileset_3
```

**SP Server**
- **Server Name**: `PETASCALE-SP02`
- **IP Address**: `9.11.53.254`
- **Port**: `1500`
- **Admin User**: `admin`
- **Status**: Installed, configured, and running (dsmserv up, DB2 connected)

---

## Backup Strategy

### Approach: Traditional File-Level Backup using BA Client

We will use IBM Storage Protect Backup-Archive (BA) Client instead of HSM Client for the following reasons:

1. **Simpler Setup**: BA Client is easier to configure for file-level backups
2. **Flexibility**: Better control over what to backup and when
3. **Scheduling**: Easy to set up automated backup schedules
4. **Restore**: Straightforward restore procedures

### Why Not HSM Client?

HSM (Hierarchical Storage Management) is designed for:
- Automatic policy-based file migration
- Transparent file recall
- Space management on GPFS filesystems
- Large-scale archival (petabyte scale)

For your use case (backing up specific filesets), BA Client is more appropriate.

---

## Implementation Plan

### Phase 1: SP Server Configuration

#### Step 1.1: Verify SP Server Status

Connect to SP Server and verify it's running:

```bash
# SSH to SP Server
ssh root@9.11.53.254

# Check dsmserv process
ps -ef | grep dsmserv

# Check DB2 instance
su - tsminst1
db2 list applications

# Connect to SP Server
dsmadmc -id=admin -password=admin@@123456789
```

Expected output: Server should be active and accepting connections.

#### Step 1.2: Create Storage Pool for GPFS Backups

```bash
# Connect to SP Server as admin
dsmadmc -id=admin -password=admin@@123456789

# Create directory storage pool for GPFS backups
DEFINE STGPOOL GPFSPOOL POOLTYPE=DIRECTORY MAXSIZE=100G

# Create storage pool volumes (adjust path as needed)
DEFINE VOLUME GPFSPOOL /data/tsmpool/gpfs FORMATSIZE=50G

# Verify storage pool
QUERY STGPOOL GPFSPOOL FORMAT=DETAILED
```

#### Step 1.3: Create Policy Domain for GPFS

```bash
# Still connected to dsmadmc

# Create policy domain
DEFINE DOMAIN GPFS_DOMAIN DESCRIPTION='GPFS Filesets Backup Domain'

# Activate the policy domain
ACTIVATE POLICYSET GPFS_DOMAIN STANDARD

# Create management class for daily backups
DEFINE MGMTCLASS GPFS_DOMAIN STANDARD GPFS_DAILY \
  DESCRIPTION='Daily backup for GPFS filesets' \
  VEREXISTS=30 \
  VERDELETED=60 \
  RETEXTRA=30 \
  RETONLY=90

# Create copy group for backup
DEFINE COPYGROUP GPFS_DOMAIN STANDARD GPFS_DAILY \
  TYPE=BACKUP \
  DESTINATION=GPFSPOOL \
  VEREXISTS=30 \
  VERDELETED=60 \
  RETEXTRA=30 \
  RETONLY=90 \
  FREQUENCY=1 \
  MODE=MODIFIED

# Assign default management class
ASSIGN DEFMGMTCLASS GPFS_DOMAIN STANDARD GPFS_DAILY

# Validate policy domain
VALIDATE POLICYSET GPFS_DOMAIN STANDARD

# Activate the policy set
ACTIVATE POLICYSET GPFS_DOMAIN STANDARD
```

#### Step 1.4: Register GPFS Node

```bash
# Register the node (p9d-vm4)
REGISTER NODE P9D-VM4 P9dVm4Password@@123 \
  DOMAIN=GPFS_DOMAIN \
  MAXNUMMP=4 \
  DEDUPLICATION=CLIENTORSERVER \
  COMPRESSION=YES \
  CONTACT='GPFS Administrator' \
  EMAILADDRESS='admin@example.com'

# Grant backup-archive privilege
GRANT AUTHORITY P9D-VM4 CLASSES=CLIENT

# Verify node registration
QUERY NODE P9D-VM4 FORMAT=DETAILED
```

---

### Phase 2: BA Client Installation on GPFS Node

#### Step 2.1: Prepare BA Client Package

On your Ansible control node:

```bash
# Copy BA Client package to p9d-vm4
scp /path/to/8.1.27.0-TIV-TSMBAC-LinuxX86.tar \
  root@p9d-vm4.storage.tucson.ibm.com:/tmp/
```

#### Step 2.2: Update Inventory File

Edit `ansible-ibm-storage-protect-2/playbooks/inventory/petascale.ini`:

```ini
[ba_clients]
p9d-vm4 ansible_host=p9d-vm4.storage.tucson.ibm.com ansible_user=root ansible_password=Carve!58boiltug
```

#### Step 2.3: Create Host Variables File

Create `ansible-ibm-storage-protect-2/playbooks/host_vars/p9d-vm4.yml`:

```yaml
---
# BA Client configuration for p9d-vm4 (GPFS node)

# BA Client version
ba_client_version: "8.1.27.0"

# OS type
os_type: "LinuxX86"

# Package location on remote node
ba_client_package_path: "/tmp/8.1.27.0-TIV-TSMBAC-LinuxX86.tar"
tar_file_location: "remote"

# Installation directories
ba_client_extract_dest: "/opt/baClient"
ba_client_temp_dest: "/tmp/"

# Service configuration
ba_client_start_daemon: true

# Installation state
ba_client_state: "present"

# SP Server connection
sp_server_name: "PETASCALE-SP02"
sp_server_address: "9.11.53.254"
sp_server_port: "1500"
node_name: "P9D-VM4"
node_password: "P9dVm4Password@@123"

# GPFS-specific backup configuration
gpfs_filesystem: "/gpfs_main"
gpfs_filesets:
  - name: "testfs"
    path: "/gpfs_main/testfs"
  - name: "fileset_1"
    path: "/gpfs_main/fileset_1"
  - name: "fileset_2"
    path: "/gpfs_main/fileset_2"
  - name: "fileset_3"
    path: "/gpfs_main/fileset_3"
```

#### Step 2.4: Install BA Client Using Ansible

```bash
# Navigate to ansible directory
cd ansible-ibm-storage-protect-2

# Test connectivity
ansible -i playbooks/inventory/petascale.ini p9d-vm4 -m ping

# Install BA Client
ansible-playbook -i playbooks/inventory/petascale.ini \
  playbooks/ba_client_install/playbooks/linux/ba_client_install_playbook.yml \
  --limit p9d-vm4
```

---

### Phase 3: BA Client Configuration

#### Step 3.1: Configure dsm.sys File

SSH to p9d-vm4 and create/edit `/opt/tivoli/tsm/client/ba/bin/dsm.sys`:

```bash
ssh root@p9d-vm4.storage.tucson.ibm.com

cat > /opt/tivoli/tsm/client/ba/bin/dsm.sys << 'EOF'
*******************************************************************************
* IBM Storage Protect Client System Options File
* Node: P9D-VM4
* Purpose: GPFS Filesets Backup
*******************************************************************************

SERVERNAME      PETASCALE-SP02

*******************************************************************************
* Server Connection Settings
*******************************************************************************
TCPSERVERADDRESS    9.11.53.254
TCPPORT             1500
NODENAME            P9D-VM4

*******************************************************************************
* Communication Settings
*******************************************************************************
COMMMETHOD          TCPIP
TCPWINDOWSIZE       256
TCPBUFFSIZE         512
TXNBYTELIMIT        25600

*******************************************************************************
* Performance Settings
*******************************************************************************
RESOURCEUTILIZATION 10
MAXCMDRETRIES       3
RETRYPERIOD         60

*******************************************************************************
* Compression and Deduplication
*******************************************************************************
COMPRESSION         YES
DEDUPLICATION       YES

*******************************************************************************
* Logging and Error Handling
*******************************************************************************
ERRORLOGNAME        /var/log/tsm/dsmerror.log
ERRORLOGRETENTION   30 D
SCHEDLOGNAME        /var/log/tsm/dsmsched.log
SCHEDLOGRETENTION   30 D

*******************************************************************************
* Backup Settings
*******************************************************************************
SUBDIR              YES
FOLLOWSYMBOLIC      NO
SKIPNTPERMISSIONS   NO

*******************************************************************************
* Domain (What to Backup)
*******************************************************************************
DOMAIN              /gpfs_main/testfs
DOMAIN              /gpfs_main/fileset_1
DOMAIN              /gpfs_main/fileset_2
DOMAIN              /gpfs_main/fileset_3

*******************************************************************************
* Include/Exclude Rules
*******************************************************************************
* Exclude temporary and cache files
EXCLUDE.DIR         /gpfs_main/*/tmp
EXCLUDE.DIR         /gpfs_main/*/cache
EXCLUDE             /gpfs_main/*/.snapshot/.../*
EXCLUDE             /gpfs_main/*/lost+found/.../*

* Include all other files
INCLUDE             /gpfs_main/testfs/.../*
INCLUDE             /gpfs_main/fileset_1/.../*
INCLUDE             /gpfs_main/fileset_2/.../*
INCLUDE             /gpfs_main/fileset_3/.../*

EOF
```

#### Step 3.2: Configure dsm.opt File

Create `/opt/tivoli/tsm/client/ba/bin/dsm.opt`:

```bash
cat > /opt/tivoli/tsm/client/ba/bin/dsm.opt << 'EOF'
*******************************************************************************
* IBM Storage Protect Client User Options File
*******************************************************************************

SERVERNAME          PETASCALE-SP02

EOF
```

#### Step 3.3: Set Permissions

```bash
# Create log directory
mkdir -p /var/log/tsm
chown root:root /var/log/tsm
chmod 755 /var/log/tsm

# Set permissions on configuration files
chmod 600 /opt/tivoli/tsm/client/ba/bin/dsm.sys
chmod 600 /opt/tivoli/tsm/client/ba/bin/dsm.opt
```

#### Step 3.4: Set Node Password

```bash
# Set the node password
dsmc set password P9dVm4Password@@123 P9dVm4Password@@123

# Test connection
dsmc query session
```

Expected output: Should show connection to PETASCALE-SP02.

---

### Phase 4: Initial Backup Test

#### Step 4.1: Create Test Data

```bash
# Create some test files in each fileset
echo "Test file in testfs" > /gpfs_main/testfs/test1.txt
echo "Test file in fileset_1" > /gpfs_main/fileset_1/test1.txt
echo "Test file in fileset_2" > /gpfs_main/fileset_2/test1.txt
echo "Test file in fileset_3" > /gpfs_main/fileset_3/test1.txt

# Verify files
ls -la /gpfs_main/*/test1.txt
```

#### Step 4.2: Perform Manual Backup

```bash
# Backup a single fileset first (testfs)
dsmc incremental /gpfs_main/testfs -subdir=yes

# Check backup status
dsmc query backup /gpfs_main/testfs/.../*

# If successful, backup all filesets
dsmc incremental /gpfs_main/testfs -subdir=yes
dsmc incremental /gpfs_main/fileset_1 -subdir=yes
dsmc incremental /gpfs_main/fileset_2 -subdir=yes
dsmc incremental /gpfs_main/fileset_3 -subdir=yes
```

#### Step 4.3: Verify Backup on SP Server

```bash
# On SP Server
dsmadmc -id=admin -password=admin@@123456789

# Query backed up files
QUERY OCCUPANCY P9D-VM4

# Query backup details
QUERY BACKUP P9D-VM4 /gpfs_main/testfs/.../*

# Check storage pool usage
QUERY STGPOOL GPFSPOOL
```

---

### Phase 5: Configure Automated Backups

#### Step 5.1: Create Backup Schedules on SP Server

```bash
# Connect to SP Server
dsmadmc -id=admin -password=admin@@123456789

# Create daily backup schedule for all filesets
DEFINE SCHEDULE GPFS_DOMAIN DAILY_GPFS_BACKUP \
  DESCRIPTION='Daily incremental backup of GPFS filesets' \
  ACTION=INCREMENTAL \
  STARTDATE=TODAY \
  STARTTIME=02:00 \
  DURATION=4 \
  DURUNITS=HOURS \
  PERIOD=1 \
  PERUNITS=DAYS \
  DAYOFWEEK=ANY \
  OBJECTS='/gpfs_main/testfs /gpfs_main/fileset_1 /gpfs_main/fileset_2 /gpfs_main/fileset_3' \
  OPTIONS='-subdir=yes'

# Associate schedule with node
DEFINE ASSOCIATION GPFS_DOMAIN DAILY_GPFS_BACKUP P9D-VM4

# Create weekly full backup schedule
DEFINE SCHEDULE GPFS_DOMAIN WEEKLY_GPFS_FULL \
  DESCRIPTION='Weekly full backup of GPFS filesets' \
  ACTION=INCREMENTAL \
  STARTDATE=TODAY \
  STARTTIME=00:00 \
  DURATION=8 \
  DURUNITS=HOURS \
  PERIOD=1 \
  PERUNITS=WEEKS \
  DAYOFWEEK=SUNDAY \
  OBJECTS='/gpfs_main/testfs /gpfs_main/fileset_1 /gpfs_main/fileset_2 /gpfs_main/fileset_3' \
  OPTIONS='-subdir=yes'

# Associate weekly schedule
DEFINE ASSOCIATION GPFS_DOMAIN WEEKLY_GPFS_FULL P9D-VM4

# Verify schedules
QUERY SCHEDULE GPFS_DOMAIN
QUERY ASSOCIATION GPFS_DOMAIN P9D-VM4
```

#### Step 5.2: Start Client Scheduler on p9d-vm4

```bash
# On p9d-vm4
# Start the scheduler daemon
dsmc schedule

# Or start as a service
systemctl start dsmcad
systemctl enable dsmcad

# Verify scheduler is running
ps -ef | grep dsmc
systemctl status dsmcad

# Check schedule
dsmc query schedule
```

---

### Phase 6: Monitoring and Verification

#### Step 6.1: Monitor Backup Jobs

On SP Server:

```bash
dsmadmc -id=admin -password=admin@@123456789

# Check current sessions
QUERY SESSION

# Check recent backup events
QUERY EVENT * * BEGIND=-1 BEGINT=00:00

# Check schedule status
QUERY SCHEDULE GPFS_DOMAIN

# Check node status
QUERY NODE P9D-VM4 FORMAT=DETAILED

# Check occupancy
QUERY OCCUPANCY P9D-VM4
```

#### Step 6.2: Review Logs

On p9d-vm4:

```bash
# Check error log
tail -f /var/log/tsm/dsmerror.log

# Check schedule log
tail -f /var/log/tsm/dsmsched.log

# Check for any issues
grep -i error /var/log/tsm/dsmerror.log
grep -i failed /var/log/tsm/dsmsched.log
```

---

### Phase 7: Test Restore Operation

#### Step 7.1: Test File Restore

```bash
# On p9d-vm4

# List backed up files
dsmc query backup /gpfs_main/testfs/test1.txt

# Restore a single file to a different location
dsmc restore /gpfs_main/testfs/test1.txt /tmp/restored_test1.txt

# Verify restored file
cat /tmp/restored_test1.txt
diff /gpfs_main/testfs/test1.txt /tmp/restored_test1.txt

# Restore entire fileset (to original location)
dsmc restore /gpfs_main/testfs/.../* -replace=yes -subdir=yes
```

#### Step 7.2: Test Point-in-Time Restore

```bash
# Restore files from a specific date
dsmc restore /gpfs_main/fileset_1/.../* \
  -pitdate=12/31/2026 \
  -pittime=23:59:59 \
  -replace=no \
  -subdir=yes
```

---

## Backup Schedule Summary

| Schedule Name | Type | Frequency | Start Time | Duration | Objects |
|--------------|------|-----------|------------|----------|---------|
| DAILY_GPFS_BACKUP | Incremental | Daily | 02:00 | 4 hours | All filesets |
| WEEKLY_GPFS_FULL | Incremental | Weekly (Sunday) | 00:00 | 8 hours | All filesets |

---

## Maintenance Tasks

### Daily Tasks

1. **Monitor Backup Status**
   ```bash
   dsmadmc -id=admin -password=admin@@123456789 "QUERY EVENT * * BEGIND=-1"
   ```

2. **Check Storage Pool Usage**
   ```bash
   dsmadmc -id=admin -password=admin@@123456789 "QUERY STGPOOL GPFSPOOL"
   ```

### Weekly Tasks

1. **Review Backup Logs**
   ```bash
   grep -i error /var/log/tsm/dsmerror.log | tail -100
   ```

2. **Verify Schedule Execution**
   ```bash
   dsmadmc -id=admin -password=admin@@123456789 "QUERY SCHEDULE GPFS_DOMAIN"
   ```

3. **Check Node Occupancy**
   ```bash
   dsmadmc -id=admin -password=admin@@123456789 "QUERY OCCUPANCY P9D-VM4"
   ```

### Monthly Tasks

1. **Test Restore Operation**
   - Perform test restore of random files
   - Verify data integrity

2. **Review Retention Policies**
   - Ensure policies align with business requirements

3. **Storage Pool Maintenance**
   ```bash
   dsmadmc -id=admin -password=admin@@123456789 "EXPIRE INVENTORY"
   ```

---

## Troubleshooting Guide

### Issue: Cannot Connect to SP Server

**Symptoms**: `ANS1017E Session rejected: TCP/IP connection failure`

**Solutions**:
1. Verify SP Server is running: `ps -ef | grep dsmserv`
2. Check network connectivity: `ping 9.11.53.254`
3. Verify port is open: `telnet 9.11.53.254 1500`
4. Check firewall rules on both nodes

### Issue: Authentication Failed

**Symptoms**: `ANS1035S Options file could not be found, or it cannot be read`

**Solutions**:
1. Verify dsm.sys exists: `ls -la /opt/tivoli/tsm/client/ba/bin/dsm.sys`
2. Check node password: `dsmc query session`
3. Reset password if needed: `dsmc set password`

### Issue: Backup Fails with "Access Denied"

**Symptoms**: `ANS1228E Sending of object failed`

**Solutions**:
1. Check file permissions on GPFS
2. Verify BA Client is running as root
3. Check GPFS mount status: `df -h | grep gpfs_main`

### Issue: Scheduler Not Running

**Symptoms**: Scheduled backups not executing

**Solutions**:
1. Check dsmcad service: `systemctl status dsmcad`
2. Restart scheduler: `systemctl restart dsmcad`
3. Verify schedule on server: `QUERY ASSOCIATION GPFS_DOMAIN P9D-VM4`

---

## Quick Reference Commands

### On GPFS Node (p9d-vm4)

```bash
# Manual backup
dsmc incremental /gpfs_main/testfs -subdir=yes

# Query backed up files
dsmc query backup /gpfs_main/testfs/.../*

# Restore files
dsmc restore /gpfs_main/testfs/.../* -replace=no -subdir=yes

# Check connection
dsmc query session

# View schedules
dsmc query schedule

# Check scheduler status
systemctl status dsmcad
```

### On SP Server (9.11.53.254)

```bash
# Connect to admin console
dsmadmc -id=admin -password=admin@@123456789

# Check node status
QUERY NODE P9D-VM4

# Check occupancy
QUERY OCCUPANCY P9D-VM4

# Check schedules
QUERY SCHEDULE GPFS_DOMAIN

# Check storage pool
QUERY STGPOOL GPFSPOOL

# Check recent events
QUERY EVENT * * BEGIND=-1
```

---

## Next Steps

1. ✅ Review this plan with your team
2. ⬜ Verify SP Server is accessible from p9d-vm4
3. ⬜ Copy BA Client package to p9d-vm4
4. ⬜ Execute Phase 1: SP Server Configuration
5. ⬜ Execute Phase 2: BA Client Installation
6. ⬜ Execute Phase 3: BA Client Configuration
7. ⬜ Execute Phase 4: Initial Backup Test
8. ⬜ Execute Phase 5: Configure Automated Backups
9. ⬜ Execute Phase 6: Monitoring Setup
10. ⬜ Execute Phase 7: Test Restore Operation

---

## Support and Documentation

- **IBM Storage Protect Documentation**: https://www.ibm.com/docs/en/storage-protect
- **GPFS Documentation**: https://www.ibm.com/docs/en/spectrum-scale
- **Ansible Playbooks**: `ansible-ibm-storage-protect-2/playbooks/`
- **Configuration Guides**: `ansible-ibm-storage-protect-2/docs/guides/`

---

**Document Version**: 1.0  
**Last Updated**: 2026-06-15  
**Author**: Bob (Ansible Planning Mode)