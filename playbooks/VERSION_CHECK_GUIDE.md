# Version Check Guide

This guide provides commands to check installed versions of IBM Storage Protect components after installation or upgrade.

## Quick Reference

| Component | Command | Description |
|-----------|---------|-------------|
| **SP Server** | `imcl listInstalledPackages` | List all installed packages with versions |
| **BA Client** | `rpm -q TIVsm-BA` | Check BA Client RPM version |
| **BA Client (detailed)** | `dsmc query session` | Check client version and server connection |
| **Installation Manager** | `imcl version` | Check Installation Manager version |

---

## SP Server Version Check

### Method 1: Using Installation Manager Command Line (Recommended)

```bash
# Full path to imcl
/opt/IBM/InstallationManager/eclipse/tools/imcl listInstalledPackages

# Output example:
# com.ibm.cic.agent_1.9.2000.20210617_0505
# com.tivoli.dsm.server_8.2.2000.20240101_1200
```

The version is shown after the underscore: `8.2.2000` = version 8.2.2.0

### Method 2: Using dsmadmc (If server is running)

```bash
# As tsminst1 user
su - tsminst1
dsmadmc -id=admin -password=yourpassword "query status"

# Output shows:
# Server Version: 8, Release 2, Level 2.0
```

### Method 3: Check server executable

```bash
# Check the server binary version
/opt/tivoli/tsm/server/bin/dsmserv version

# Or check the installed files
ls -la /opt/tivoli/tsm/server/bin/
```

---

## BA Client Version Check

### Method 1: Using RPM Query (Recommended)

```bash
# Check installed BA Client package
rpm -q TIVsm-BA

# Output example:
# TIVsm-BA-8.2.1.0-0.x86_64
```

### Method 2: Using dsmc command

```bash
# Check client version
dsmc query session

# Output shows:
# IBM Storage Protect
# Command Line Backup-Archive Client Interface
# Client Version 8, Release 2, Level 1.0
```

### Method 3: Check specific RPM packages

```bash
# List all TSM/SP related packages
rpm -qa | grep -i tiv

# Output example:
# TIVsm-API64-8.2.1.0-0.x86_64
# TIVsm-BA-8.2.1.0-0.x86_64
# gskcrypt64-8.0.55.24.linux.x86_64
# gskssl64-8.0.55.24.linux.x86_64
```

### Method 4: Check daemon version

```bash
# Check the daemon version
/opt/tivoli/tsm/client/ba/bin/dsmcad -optfile=/opt/tivoli/tsm/client/ba/bin/dsm.opt version

# Or check the binary
/opt/tivoli/tsm/client/ba/bin/dsmc -version
```

---

## Installation Manager Version Check

```bash
# Check Installation Manager version
/opt/IBM/InstallationManager/eclipse/tools/imcl version

# Output example:
# IBM Installation Manager 1.9.2
```

---

## Ansible Playbook for Version Checking

You can also use Ansible to check versions across multiple hosts:

### Check SP Server Versions

```bash
ansible sp_servers -i playbooks/inventory/petascale.ini \
  -m shell \
  -a "/opt/IBM/InstallationManager/eclipse/tools/imcl listInstalledPackages | grep dsm.server" \
  --become
```

### Check BA Client Versions

```bash
ansible ba_clients -i playbooks/inventory/petascale.ini \
  -m shell \
  -a "rpm -q TIVsm-BA" \
  --become
```

### Check All Versions (Combined)

```bash
ansible all -i playbooks/inventory/petascale.ini \
  -m shell \
  -a "echo 'SP Server:' && /opt/IBM/InstallationManager/eclipse/tools/imcl listInstalledPackages 2>/dev/null | grep dsm.server || echo 'Not installed'; echo 'BA Client:' && rpm -q TIVsm-BA 2>/dev/null || echo 'Not installed'" \
  --become
```

---

## Post-Installation Verification

### SP Server Post-Installation Checks

```bash
# 1. Check version
/opt/IBM/InstallationManager/eclipse/tools/imcl listInstalledPackages | grep dsm.server

# 2. Check if server is running
ps -ef | grep dsmserv

# 3. Check server status (as tsminst1)
su - tsminst1
dsmadmc -id=admin -password=yourpassword "query status"

# 4. Check database status
dsmadmc -id=admin -password=yourpassword "query db"

# 5. Check active log
dsmadmc -id=admin -password=yourpassword "query log"
```

### BA Client Post-Installation Checks

```bash
# 1. Check version
rpm -q TIVsm-BA

# 2. Check if daemon is running
systemctl status dsmcad

# 3. Test client connection
dsmc query session

# 4. Check configuration
cat /opt/tivoli/tsm/client/ba/bin/dsm.opt
cat /opt/tivoli/tsm/client/ba/bin/dsm.sys

# 5. Test backup (if configured)
dsmc incremental /tmp/test.txt
```

---

## Version Comparison

### Compare Versions Across Hosts

Create a simple script to compare versions:

```bash
#!/bin/bash
# save as check_versions.sh

echo "=== SP Server Versions ==="
ansible sp_servers -i playbooks/inventory/petascale.ini \
  -m shell \
  -a "/opt/IBM/InstallationManager/eclipse/tools/imcl listInstalledPackages | grep dsm.server | awk -F'_' '{print \$2}'" \
  --become | grep -v ">>>"

echo ""
echo "=== BA Client Versions ==="
ansible ba_clients -i playbooks/inventory/petascale.ini \
  -m shell \
  -a "rpm -q TIVsm-BA | awk -F'-' '{print \$3}'" \
  --become | grep -v ">>>"
```

---

## Troubleshooting Version Issues

### Issue: Command Not Found

**Problem:** `imcl: command not found`

**Solution:**
```bash
# Use full path
/opt/IBM/InstallationManager/eclipse/tools/imcl listInstalledPackages

# Or add to PATH
export PATH=$PATH:/opt/IBM/InstallationManager/eclipse/tools
```

### Issue: Permission Denied

**Problem:** Permission denied when running commands

**Solution:**
```bash
# Run as root or with sudo
sudo /opt/IBM/InstallationManager/eclipse/tools/imcl listInstalledPackages

# Or switch to tsminst1 for SP Server commands
su - tsminst1
```

### Issue: Package Not Found

**Problem:** `package ... is not installed`

**Solution:**
```bash
# Verify installation
rpm -qa | grep -i tiv
ls -la /opt/tivoli/tsm/

# Check installation logs
cat /var/log/messages | grep -i tsm
journalctl | grep -i tsm
```

---

## Version Format Reference

### SP Server Version Format

```
com.tivoli.dsm.server_8.2.2000.20240101_1200
                        │ │ │
                        │ │ └─ Level (2000 = 2.0)
                        │ └─── Release (2)
                        └───── Version (8)

Displayed as: 8.2.2.0 or 8.2.2.000
```

### BA Client Version Format

```
TIVsm-BA-8.2.1.0-0.x86_64
         │ │ │ │
         │ │ │ └─ Level (1.0)
         │ │ └─── Release (2)
         └─────── Version (8)

Displayed as: 8.2.1.0
```

---

## Quick Commands Summary

```bash
# SP Server
/opt/IBM/InstallationManager/eclipse/tools/imcl listInstalledPackages | grep dsm.server

# BA Client
rpm -q TIVsm-BA

# All TSM/SP packages
rpm -qa | grep -i tiv

# Check services
systemctl status dsmcad        # BA Client daemon
ps -ef | grep dsmserv          # SP Server process

# Test connectivity
dsmc query session             # BA Client to SP Server
```

---

## Additional Resources

- **IBM Documentation:** [IBM Storage Protect Knowledge Center](https://www.ibm.com/docs/en/storage-protect)
- **Installation Logs:** `/var/log/messages`, `/tmp/installmgr*.log`
- **Configuration Files:**
  - SP Server: `/opt/tivoli/tsm/server/bin/dsmserv.opt`
  - BA Client: `/opt/tivoli/tsm/client/ba/bin/dsm.opt`

---

## Need Help?

If you encounter issues checking versions:
1. Verify the component is installed
2. Check you have appropriate permissions
3. Review installation logs
4. Consult the main playbook documentation

For automated version checking across your environment, use the Ansible ad-hoc commands provided above.

---

**Last Updated:** 2026-05-04  
**Maintained by:** IBM Storage Protect Ansible Team