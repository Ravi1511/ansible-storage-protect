# Petascale Deployment - Complete Guide

## Overview
This guide explains how to set up and run the petascale deployment playbooks for installing, upgrading, and uninstalling IBM Storage Protect components across your infrastructure.

## Available Playbooks

1. **petascale_install.yml** - Install SP Server, HSM Client, and BA Client
2. **petascale_upgrade.yml** - Upgrade existing installations
3. **petascale_uninstall.yml** - Uninstall components safely

## Component Overview

| Component | Description | Inventory Group |
|-----------|-------------|-----------------|
| **SP Server** | IBM Storage Protect Server | `sp_servers` |
| **HSM Client** | Hierarchical Storage Management Client | `hsm_clients` |
| **BA Client** | Backup-Archive Client | `ba_clients` |

## ⚠️ CRITICAL: Node Separation Requirement

**SP Server and BA/HSM Clients MUST be installed on SEPARATE nodes!**

### Why This Is Critical:

Different components require **incompatible GSKit versions**:
- **SP Server 8.1.27**: Requires GSKit 8.0.55.31
- **BA/HSM Client 8.1.x**: Requires GSKit 8.0.60.1

### The Problem:

1. **Installing BA/HSM Client on SP Server node** will overwrite SP Server's GSKit (8.0.55.31 → 8.0.60.1), causing SP Server to malfunction
2. **Uninstalling BA/HSM Client** will remove GSKit entirely, making SP Server unusable

### Correct Architecture:

```
✅ CORRECT - Separate Nodes:
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│ SP Server   │  │ BA Client   │  │ HSM Client  │
│ Node 1      │  │ Node 2      │  │ Node 3      │
│ GSKit 8.55  │  │ GSKit 8.60  │  │ GSKit 8.60  │
└─────────────┘  └─────────────┘  └─────────────┘

❌ INCORRECT - Same Node:
┌──────────────────────┐
│ SP Server + BA Client│  ← GSKit conflict!
│ Node 1               │
└──────────────────────┘
```

### Inventory Configuration Example:

```ini
# ✅ CORRECT
[sp_servers]
sp-server-01

[ba_clients]
ba-client-01
ba-client-02

[hsm_clients]
hsm-client-01

# ❌ NEVER DO THIS
[sp_servers]
server-01

[ba_clients]
server-01  ← Same node as SP Server - WILL BREAK!
```

**Always ensure SP Server nodes are separate from BA/HSM Client nodes in your inventory.**

## Quick Links

- [Installation Guide](#installation-guide)
- [Upgrade Guide](#upgrade-guide)
- [Uninstallation Guide](#uninstallation-guide)
- [Configuration Guide](CONFIGURATION_GUIDE.md) - Detailed configuration instructions
- [Host Variables](host_vars/README.md) - Per-host configuration
- [Group Variables](group_vars/README.md) - Group-level configuration

---

# Installation Guide

## Installation Order

The playbook installs components in this order:
1. **SP Server** (first, requires `--tags install`)
2. **HSM Client** (second)
3. **BA Client** (third)

## Prerequisites

### Automated Dependency Validation

The petascale playbooks now include **automated dependency validation** that checks all required dependencies before installation. The validation:

- ✅ Checks Python 3.9+, Java, lsof, rsync
- ✅ Validates /tmp permissions, mount options, and disk space
- ✅ Provides detailed remediation reports with step-by-step instructions
- ✅ Optionally auto-installs missing dependencies (non-production use)

**Default Behavior**: Validation only (no automatic installation)

**To enable auto-install** (non-production environments only):
```bash
ansible-playbook playbooks/petascale_install.yml \
  -i playbooks/inventory/petascale.ini \
  -e "install_dependencies=true" \
  --tags install
```

### 1. Software Packages

**IMPORTANT**: All software packages must be present on the **REMOTE NODES** (target hosts), NOT on the Ansible control node.

#### SP Server Packages
- **Location**: `/tmp/` on SP Server nodes
- **Format**: `.bin` file (self-extracting binary)
- **Example**:
  - `8.1.27.000-IBM-SPSRV-LIC-DEBUG-Linuxx86_64-162.bin`
  - `8.2.2.000-IBM-SPSRV-LIC-DEBUG-Linuxx86_64-109.bin`
- **Naming Pattern**: `<version>-IBM-SPSRV-<license>-<os>-<build>.bin`

#### HSM Client Packages
- **Location**: `/tmp/` on HSM Client nodes
- **Format**: `.tar` or `.tar.Z` (compressed tar)
- **Example**: `8.1.25.0-TIV-TSMHSM-LinuxX86.tar` or `8.1.25.0-TIV-TSMHSM-AIX.tar.Z`
- **Supported OS**: Linux (x86_64, s390x, ppc64le), AIX

#### BA Client Packages
- **Location**: `/tmp/` on BA Client nodes
- **Format**: `.tar` archive
- **Example**: `8.1.25.0-TIV-TSMBAC-LinuxX86.tar`
- **Supported Architectures**: x86_64, s390x, ppc64le

### 2. System Requirements

#### All Nodes
- **Python 3.9+** installed
  - Linux: `/usr/bin/python3.9`
  - AIX: `/opt/freeware/bin/python3.9`
- **Java** (JRE or JDK) installed
  - Required for IBM Installation Manager and SP Server
  - Minimum version: Java 8
- **SSH access** with password authentication enabled
- **Root or sudo privileges**
- **lsof** package installed
- **rsync** package installed
- **/tmp permissions**: `1777` (rwxrwxrwt)
- **/tmp mount options**: Must NOT have `noexec` flag
- **/tmp disk space**: Minimum 2GB free space

#### SP Server Nodes (Additional)
- **Disk space**: Varies by deployment size (see sizing guides)
- **Supported OS**: RHEL 7.x, 8.x, 9.x

#### HSM Client Nodes (Additional)
- **GPFS** (IBM Spectrum Scale) installed and configured
- **Supported OS**: Linux (RHEL, SLES), AIX

#### BA Client Nodes (Additional)
- **Supported OS**: Linux (RHEL, SLES, Ubuntu)

### 3. Network Requirements
- All nodes must be able to reach each other
- SP Server must be accessible from all client nodes
- Firewall rules configured for SP Server ports (default: 1500)

## Setup Steps

### Step 1: Prepare Software Packages on Remote Nodes

**Option A: Copy to all nodes using Ansible**
```bash
# Copy SP Server packages
ansible sp_servers -i playbooks/inventory/petascale.ini -m copy \
  -a "src=/local/path/8.1.27.000-IBM-SPSRV-LIC-DEBUG-Linuxx86_64-162.bin dest=/tmp/ mode=0755" \
  --become

# Copy HSM Client packages
ansible hsm_clients -i playbooks/inventory/petascale.ini -m copy \
  -a "src=/local/path/8.1.25.0-TIV-TSMHSM-LinuxX86.tar dest=/tmp/ mode=0644" \
  --become

# Copy BA Client packages
ansible ba_clients -i playbooks/inventory/petascale.ini -m copy \
  -a "src=/local/path/8.1.25.0-TIV-TSMBAC-LinuxX86.tar dest=/tmp/ mode=0644" \
  --become
```

**Option B: Copy to each node individually**
```bash
# Copy to SP Server nodes
scp 8.1.27.000-IBM-SPSRV-LIC-DEBUG-Linuxx86_64-162.bin root@sp-server-01:/tmp/

# Copy to HSM Client nodes
scp 8.1.25.0-TIV-TSMHSM-LinuxX86.tar root@hsm-client-01:/tmp/

# Copy to BA Client nodes
scp 8.1.25.0-TIV-TSMBAC-LinuxX86.tar root@ba-client-01:/tmp/
```

### Step 2: Verify Package Presence on Remote Nodes

```bash
# Verify SP Server packages
ansible sp_servers -i playbooks/inventory/petascale.ini -m shell \
  -a "ls -lh /tmp/*.bin" --become

# Verify HSM Client packages
ansible hsm_clients -i playbooks/inventory/petascale.ini -m shell \
  -a "ls -lh /tmp/*.tar*" --become

# Verify BA Client packages
ansible ba_clients -i playbooks/inventory/petascale.ini -m shell \
  -a "ls -lh /tmp/*.tar" --become
```

### Step 3: Configure Inventory File

Create `playbooks/inventory/petascale.ini`:

```ini
[sp_servers]
sp-server-01 ansible_host=192.168.1.10 ansible_user=root

[hsm_clients]
hsm-client-01 ansible_host=192.168.1.30 ansible_user=root

[ba_clients]
ba-client-01 ansible_host=192.168.1.20 ansible_user=root
ba-client-02 ansible_host=192.168.1.21 ansible_user=root
ba-client-03 ansible_host=192.168.1.22 ansible_user=root

[all:children]
sp_servers
hsm_clients
ba_clients
```

### Step 4: Configure Host Variables

Create host-specific configuration files in `playbooks/host_vars/`:

**SP Server Example** (`playbooks/host_vars/sp-server-01.yml`):
```yaml
---
# SP Server Configuration
sp_server_version: "8.1.25.0"
sp_server_package_path: "/tmp/8.1.25.0-IBM-SPSRV-LinuxX86.tar"
sp_server_install_dest: "/opt/sp_server_binary/"
sp_server_instance_dir: "/opt/tivoli/tsm/server1/TSMServer1"
sp_server_db_dir: "/tsminst1/TSMdbspace"
sp_server_active_log_dir: "/tsminst1/TSMalog"
sp_server_archive_log_dir: "/tsminst1/TSMarchlog"
```

**HSM Client Example** (`playbooks/host_vars/hsm-client-01.yml`):
```yaml
---
# HSM Client Configuration
hsm_client_version: "8.1.25.0"
hsm_client_package_path: "/tmp/8.1.25.0-TIV-TSMHSM-LinuxX86.tar"
hsm_client_extract_dest: "/opt/hsmClient"
hsm_client_state: "present"
```

**BA Client Example** (`playbooks/host_vars/ba-client-01.yml`):
```yaml
---
# BA Client Configuration
ba_client_version: "8.1.25.0"
ba_client_package_path: "/tmp/8.1.25.0-TIV-TSMBAC-LinuxX86.tar"
ba_client_extract_dest: "/opt/baClient"
ba_client_state: "present"
ba_client_start_daemon: false
```

### Step 5: Verify Prerequisites

```bash
# Test connectivity to all hosts
ansible all -i playbooks/inventory/petascale.ini -m ping

# Verify Python 3.9 on all nodes
ansible all -i playbooks/inventory/petascale.ini -m raw -a "python3.9 --version"

# Verify packages exist on all nodes
ansible all -i playbooks/inventory/petascale.ini -m shell \
  -a "ls -lh /tmp/*.tar* /tmp/*.bin 2>/dev/null || echo 'No packages found'" \
  --become
```

## Running the Installation Playbook

### Install ALL Components (BA Client + HSM Client + SP Server)

```bash
ansible-playbook playbooks/petascale_install.yml \
  -i playbooks/inventory/petascale.ini \
  --tags install
```

**Note**: SP Server installation requires the `--tags install` flag as a safety measure.

### Install ONLY BA Client and HSM Client (Skip SP Server)

```bash
# Use --limit to exclude sp_servers group
ansible-playbook playbooks/petascale_install.yml \
  -i playbooks/inventory/petascale.ini \
  --limit 'all:!sp_servers'
```

### Install Specific Component Groups

```bash
# Install only BA Clients
ansible-playbook playbooks/petascale_install.yml \
  -i playbooks/inventory/petascale.ini \
  --limit ba_clients

# Install only HSM Clients
ansible-playbook playbooks/petascale_install.yml \
  -i playbooks/inventory/petascale.ini \
  --limit hsm_clients

# Install only SP Servers
ansible-playbook playbooks/petascale_install.yml \
  -i playbooks/inventory/petascale.ini \
  --limit sp_servers \
  --tags install
```

### Install on Specific Hosts

```bash
# Install on specific hosts
ansible-playbook playbooks/petascale_install.yml \
  -i playbooks/inventory/petascale.ini \
  --limit ba-client-01,hsm-client-01

# Install on single host
ansible-playbook playbooks/petascale_install.yml \
  -i playbooks/inventory/petascale.ini \
  --limit sp-server-01 \
  --tags install
```

### Installation with Custom Variables

```bash
# Use custom variables file
ansible-playbook playbooks/petascale_install.yml \
  -i playbooks/inventory/petascale.ini \
  -e @playbooks/vars/custom_vars.yml \
  --tags install
```

### Dry Run (Check Mode)

```bash
# Check what would be installed without actually installing
ansible-playbook playbooks/petascale_install.yml \
  -i playbooks/inventory/petascale.ini \
  --check
```

---

# Upgrade Guide

## Overview

The `petascale_upgrade.yml` playbook upgrades existing installations to newer versions.

## Upgrade Order

Components are upgraded in this order:
1. **BA Client** (first)
2. **HSM Client** (second)
3. **SP Server** (third)

## Prerequisites

- All components must be currently installed
- New version packages must be on remote nodes
- Backup of current configuration recommended

## Running the Upgrade Playbook

### Upgrade All Components

```bash
ansible-playbook playbooks/petascale_upgrade.yml \
  -i playbooks/inventory/petascale.ini
```

### Upgrade Specific Component Groups

```bash
# Upgrade only BA Clients
ansible-playbook playbooks/petascale_upgrade.yml \
  -i playbooks/inventory/petascale.ini \
  --limit ba_clients

# Upgrade only HSM Clients
ansible-playbook playbooks/petascale_upgrade.yml \
  -i playbooks/inventory/petascale.ini \
  --limit hsm_clients

# Upgrade only SP Servers
ansible-playbook playbooks/petascale_upgrade.yml \
  -i playbooks/inventory/petascale.ini \
  --limit sp_servers
```

### Upgrade Specific Hosts

```bash
# Upgrade specific hosts
ansible-playbook playbooks/petascale_upgrade.yml \
  -i playbooks/inventory/petascale.ini \
  --limit ba-client-01,ba-client-02
```

---

# Uninstallation Guide

## Overview

The `petascale_uninstall.yml` playbook safely removes IBM Storage Protect components from nodes.

## Uninstallation Order

Components are uninstalled in reverse order of installation:
1. **BA Client** (first)
2. **HSM Client** (second)
3. **SP Server** (third)

## Safety Features

- ⚠️ **Confirmation Required** - Must pass `-e "confirm_uninstall=yes"`
- 🔄 **Automatic Rollback** - Reinstalls packages if uninstall fails
- 💾 **Configuration Backup** - Backs up configuration files
- 📦 **Package Backup** - Backs up RPMs for potential reinstall
- ✅ **Data Preservation** - Backed up data on SP Server is NOT deleted

## What Gets Removed

### SP Server
- ✓ SP Server software (via Installation Manager)
- ✓ SP Server instance (stopped)
- ✓ SP Server processes (`dsmserv`) terminated

### HSM Client
- ✓ HSM Client software packages (RPMs: TIVsm-HSM)

### BA Client
- ✓ BA Client software packages (RPMs: TIVsm-BA)
- ✓ BA Client daemon (`dsmcad.service`) stopped
- ✓ BA Client processes (`dsmc`, `dsmcad`) terminated

## What Gets Preserved

- ✓ Configuration files (backed up to .bk files)
- ✓ RPM packages (backed up to /opt/*ClientPackagesBk)
- ✓ Backed up data on SP Server
- ✓ Node registrations on SP Server
- ✓ Backup history on SP Server
- ✓ Database files (SP Server)

## Uninstallation Usage

### Uninstall All Components

```bash
# Step 1: Review what will be uninstalled (without confirmation)
ansible-playbook playbooks/petascale_uninstall.yml \
  -i playbooks/inventory/petascale.ini

# Step 2: Proceed with uninstall (with confirmation)
ansible-playbook playbooks/petascale_uninstall.yml \
  -i playbooks/inventory/petascale.ini \
  -e "confirm_uninstall=yes"
```

### Uninstall Specific Component Groups

```bash
# Uninstall only SP Servers
ansible-playbook playbooks/petascale_uninstall.yml \
  -i playbooks/inventory/petascale.ini \
  -e "confirm_uninstall=yes" \
  --limit sp_servers

# Uninstall only HSM Clients
ansible-playbook playbooks/petascale_uninstall.yml \
  -i playbooks/inventory/petascale.ini \
  -e "confirm_uninstall=yes" \
  --limit hsm_clients

# Uninstall only BA Clients
ansible-playbook playbooks/petascale_uninstall.yml \
  -i playbooks/inventory/petascale.ini \
  -e "confirm_uninstall=yes" \
  --limit ba_clients
```

### Uninstall Specific Hosts

```bash
# Uninstall from specific hosts
ansible-playbook playbooks/petascale_uninstall.yml \
  -i playbooks/inventory/petascale.ini \
  -e "confirm_uninstall=yes" \
  --limit ba-client-01,hsm-client-01

# Uninstall from single host
ansible-playbook playbooks/petascale_uninstall.yml \
  -i playbooks/inventory/petascale.ini \
  -e "confirm_uninstall=yes" \
  --limit sp-server-01
```

### Dry Run (Check Mode)

```bash
# Check what would be uninstalled without actually doing it
ansible-playbook playbooks/petascale_uninstall.yml \
  -i playbooks/inventory/petascale.ini \
  -e "confirm_uninstall=yes" \
  --check
```

### Verbose Output

```bash
# Use -v for detailed progress information
ansible-playbook playbooks/petascale_uninstall.yml \
  -i playbooks/inventory/petascale.ini \
  -e "confirm_uninstall=yes" \
  -v
```

---

# Configuration Management

## Variable Precedence

Variables are loaded in this order (highest to lowest priority):

1. **Command-line variables** (`-e` flag) - Highest priority
2. **Host variables** (`playbooks/host_vars/<hostname>.yml`)
3. **Group variables** (`playbooks/group_vars/<groupname>.yml`)
4. **Global variables** (`playbooks/group_vars/all.yml`)
5. **Role defaults** - Lowest priority

## Configuration Files

### Inventory File
- **Location**: `playbooks/inventory/petascale.ini`
- **Purpose**: Define hosts and groups
- **Example**: See [Step 3: Configure Inventory File](#step-3-configure-inventory-file)

### Global Variables
- **Location**: `playbooks/group_vars/all.yml`
- **Purpose**: Set defaults for all hosts
- **Variables**: Common settings like package locations, versions

### Group Variables
- **SP Servers**: `playbooks/group_vars/sp_servers.yml`
- **HSM Clients**: `playbooks/group_vars/hsm_clients.yml`
- **BA Clients**: `playbooks/group_vars/ba_clients.yml`
- **Purpose**: Set defaults for each component type

### Host Variables
- **Location**: `playbooks/host_vars/<hostname>.yml`
- **Purpose**: Customize settings for individual hosts
- **Priority**: Overrides all group and global variables

## Playbook Execution Flow

### Installation Flow

1. **OS Detection**
   - Detects Linux vs AIX
   - Sets appropriate Python interpreter path

2. **Python 3.9 Validation**
   - Checks all nodes for Python 3.9 presence
   - Reports status for each node
   - Continues even if Python 3.9 is missing (will fail later if needed)

3. **System Requirements Check** (SP Server only)
   - Validates /tmp mount options (no noexec)
   - Validates /tmp permissions (1777)
   - Checks for required packages (lsof, rsync)

4. **Component Installation**
   - Checks if component is already installed
   - Skips installation if already present (idempotent)
   - For nodes without component:
     - Validates package availability on remote node
     - Performs system compatibility checks
     - Installs component and dependencies
     - Verifies installation

5. **Installation Summary**
   - Reports which nodes had component already installed
   - Reports which nodes received new installations
   - Reports any installation failures
   - Fails playbook if any installations failed

---

# Troubleshooting

### Dependency Validation

#### Issue: Dependency validation fails

**Error:**
```
DEPENDENCY VALIDATION FAILED - hostname
Missing or misconfigured dependencies detected.
```

**Solution:**

1. **Review the remediation report** displayed in the output
2. **Follow the step-by-step instructions** for each missing dependency
3. **For production systems**: Manually install dependencies
4. **For non-production systems**: Use auto-install flag

```bash
# Production (recommended): Manual installation
# Follow remediation report instructions for each dependency

# Non-production: Auto-install
ansible-playbook playbooks/petascale_install.yml \
  -i playbooks/inventory/petascale.ini \
  -e "install_dependencies=true" \
  --tags install
```

#### Issue: Auto-install fails for some dependencies

**Behavior:**
Some dependencies like /tmp mount options or disk space cannot be auto-installed.

**Solution:**
These require manual intervention:

```bash
# Fix /tmp mount options
sudo mount -o remount,exec /tmp
# Make permanent by editing /etc/fstab

# Fix /tmp disk space
sudo find /tmp -type f -atime +7 -delete
# Or increase filesystem size
```

## Common Issues

### Issue 1: Package Not Found on Remote Node

**Error:**
```
FAILED! => {"msg": "Package not found on <hostname>! Expected location: /tmp/<package>.tar"}
```

**Solution:**
```bash
# Copy package to the remote node
scp <package>.tar root@<hostname>:/tmp/

# Verify package is present
ansible <hostname> -i playbooks/inventory/petascale.ini -m stat \
  -a "path=/tmp/<package>.tar" --become
```

### Issue 2: Python 3.9 Not Found

**Error:**
```
WARNING: Python 3.9 is ABSENT on <hostname>
```

**Solution:**
Install Python 3.9 on the target host:

**Linux:**
```bash
# RHEL/CentOS
yum install python39

# Ubuntu/Debian
apt-get install python3.9
```

**AIX:**
```bash
# Install from AIX Toolbox
yum install python39
```

### Issue 3: /tmp Mount Options (SP Server)

**Error:**
```
ERROR: /tmp is mounted with 'noexec' flag on <hostname>
```

**Solution:**
```bash
# Temporary fix (until reboot)
sudo mount -o remount,exec /tmp

# Permanent fix
# 1. Edit /etc/fstab
# 2. Remove 'noexec' from /tmp mount options
# 3. Save and remount
sudo mount -o remount /tmp
```

### Issue 4: /tmp Permissions (SP Server)

**Error:**
```
ERROR: /tmp has incorrect permissions on <hostname>
Current: 755
Required: 1777
```

**Solution:**
```bash
sudo chmod 1777 /tmp
```

### Issue 5: Component Already Installed

**Behavior:**
The playbook will skip installation and report the node as "already_installed"

**To Force Reinstall:**
1. Use the uninstall playbook first
2. Then run the installation playbook again

### Issue 6: Architecture Mismatch

**Error:**
```
ERROR: Unsupported architecture: <arch>
Supported: x86_64, s390x, ppc64le
```

**Solution:**
Ensure you're using the correct package for your system architecture.

### Issue 7: Insufficient Disk Space

**Error:**
```
ERROR: Insufficient disk space in /
Available: <X> MB
Required: <Y> MB
```

**Solution:**
Free up disk space on the target node or use a different partition.

## Post-Installation Verification

### Verify SP Server Installation

```bash
# Check SP Server status
ansible sp_servers -i playbooks/inventory/petascale.ini -m shell \
  -a "/opt/IBM/InstallationManager/eclipse/tools/imcl listInstalledPackages" \
  --become

# Check SP Server version
ansible sp_servers -i playbooks/inventory/petascale.ini -m shell \
  -a "dsmadmc -id=admin -pa=password 'query status'" \
  --become
```

### Verify HSM Client Installation

```bash
# Check HSM Client packages
ansible hsm_clients -i playbooks/inventory/petascale.ini -m shell \
  -a "rpm -q TIVsm-HSM" --become

# Check HSM Client version
ansible hsm_clients -i playbooks/inventory/petascale.ini -m shell \
  -a "dsmc -version" --become
```

### Verify BA Client Installation

```bash
# Check BA Client packages
ansible ba_clients -i playbooks/inventory/petascale.ini -m shell \
  -a "rpm -q TIVsm-BA" --become

# Check BA Client version
ansible ba_clients -i playbooks/inventory/petascale.ini -m shell \
  -a "dsmc -version" --become
```

## Post-Installation Configuration

### SP Server Configuration
1. Configure database and storage pools
2. Set up administrative schedules
3. Configure client communication
4. Register client nodes

### HSM Client Configuration
1. Edit `/opt/tivoli/tsm/client/hsm/bin/dsm.sys`
2. Edit `/opt/tivoli/tsm/client/hsm/bin/dsm.opt`
3. Configure GPFS policy rules
4. Register node with SP Server

### BA Client Configuration
1. Edit `/opt/tivoli/tsm/client/ba/bin/dsm.sys`
2. Edit `/opt/tivoli/tsm/client/ba/bin/dsm.opt`
3. Register node with SP Server
4. Configure backup schedules

## Support and Documentation

### Additional Guides
- **SP Server**: `docs/guides/sp-server-lifecycle-guide.md`
- **HSM Client**: `docs/guides/storage-agent-lifecycle-guide.md`
- **BA Client**: `docs/guides/ba-client-lifecycle-guide.md`
- **Configuration**: `playbooks/CONFIGURATION_GUIDE.md`
- **Variables**: `playbooks/VARIABLE_CONFIGURATION_GUIDE.md`

### Log Files
- **SP Server**: `/opt/tivoli/tsm/server1/TSMServer1/*.log`
- **HSM Client**: `/opt/tivoli/tsm/client/hsm/bin/dsmerror.log`
- **BA Client**: `/opt/tivoli/tsm/client/ba/bin/dsmerror.log`
- **Ansible**: Check playbook output for detailed error messages

### Getting Help
For issues or questions:
1. Review the playbook output for detailed error messages
2. Check the component-specific log files
3. Consult the relevant lifecycle guide
4. Review the configuration guides