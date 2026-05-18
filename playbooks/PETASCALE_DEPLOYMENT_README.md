# Petascale Deployment - Setup Guide

## Overview
This guide explains how to set up and run the petascale deployment playbooks for installing and uninstalling BA Client on all nodes.

## Available Playbooks

1. **petascale_install.yml** - Install BA Client on nodes
2. **petascale_uninstall.yml** - Uninstall BA Client from nodes

## Quick Links

- [Installation Guide](#installation-guide)
- [Uninstallation Guide](#uninstallation-guide)
- [Configuration Guide](CONFIGURATION_GUIDE.md) - Detailed configuration instructions
- [Host Variables](host_vars/README.md) - Per-host configuration
- [Group Variables](group_vars/README.md) - Group-level configuration

---

# Installation Guide

## BA Client Package Location

**IMPORTANT**: The BA Client software packages must be present on the **REMOTE NODES** (target hosts), NOT on the Ansible control node.

The playbook checks for package availability on each remote node and fails immediately if the package is not found, avoiding time-consuming file transfers.

## Prerequisites

### 1. BA Client Software Packages
Download the IBM Storage Protect BA Client installation packages and place them on **ALL REMOTE NODES** where BA Client needs to be installed.

**Required Package Format:**
- File name pattern: `<version>-TIV-TSMBAC-LinuxX86.tar`
- Example: `8.1.25.0-TIV-TSMBAC-LinuxX86.tar`

**Supported Architectures:**
- x86_64
- s390x
- ppc64le

### 2. Package Location on Remote Nodes
The BA Client package must be present at `/tmp/` on each remote node:

```bash
# On each remote node, place the package at:
/tmp/8.1.25.0-TIV-TSMBAC-LinuxX86.tar

# You can copy it using scp from your local machine:
scp 8.1.25.0-TIV-TSMBAC-LinuxX86.tar root@remote-node:/tmp/
```

### 3. Python 3.9 Requirement
All target nodes must have Python 3.9 installed. The playbook will check for this and fail if not present.

## Required Parameters

### Playbook Variables
The following variables are configured in the playbook but can be overridden:

| Variable | Default Value | Description |
|----------|---------------|-------------|
| `ba_client_version` | `8.1.25.0` | Version of BA Client to install |
| `ba_client_package_path` | `/tmp/<version>-TIV-TSMBAC-LinuxX86.tar` | Full path to package on **remote nodes** |
| `ba_client_state` | `present` | Installation state (present/absent) |
| `ba_client_extract_dest` | `/opt/baClient` | Temporary extraction directory on remote hosts |
| `ba_client_temp_dest` | `/tmp/` | Temporary directory on remote hosts |
| `ba_client_start_daemon` | `false` | Whether to start dsmcad daemon after installation |

## Setup Steps

### Step 1: Prepare BA Client Packages on Remote Nodes

**Option A: Copy to all nodes using Ansible**
```bash
# Create a simple playbook to copy packages to all nodes
ansible all -i inventory/petascale.ini -m copy \
  -a "src=/local/path/8.1.25.0-TIV-TSMBAC-LinuxX86.tar dest=/tmp/ mode=0644" \
  --become
```

**Option B: Copy to each node individually**
```bash
# Copy to each remote node
for host in ba-client-01 ba-client-02 ba-client-03; do
  scp 8.1.25.0-TIV-TSMBAC-LinuxX86.tar root@${host}:/tmp/
done
```

**Option C: Use shared NFS/storage**
```bash
# If nodes have access to shared storage, place package there
# and create symlink on each node
ansible all -i inventory/petascale.ini -m file \
  -a "src=/shared/storage/8.1.25.0-TIV-TSMBAC-LinuxX86.tar dest=/tmp/8.1.25.0-TIV-TSMBAC-LinuxX86.tar state=link" \
  --become
```

### Step 2: Verify Package Presence on Remote Nodes

```bash
# Verify package exists on all nodes
ansible all -i inventory/petascale.ini -m stat \
  -a "path=/tmp/8.1.25.0-TIV-TSMBAC-LinuxX86.tar" \
  --become

# Check file size to ensure complete transfer
ansible all -i inventory/petascale.ini -m shell \
  -a "ls -lh /tmp/8.1.25.0-TIV-TSMBAC-LinuxX86.tar" \
  --become
```

### Step 3: Prepare Inventory File

Create an inventory file (e.g., `inventory/petascale.ini`):

```ini
[sp_servers]
sp-server-01 ansible_host=192.168.1.10 ansible_user=root

[ba_clients]
ba-client-01 ansible_host=192.168.1.20 ansible_user=root
ba-client-02 ansible_host=192.168.1.21 ansible_user=root
ba-client-03 ansible_host=192.168.1.22 ansible_user=root

[hsm_clients]
hsm-client-01 ansible_host=192.168.1.30 ansible_user=root

[all:children]
sp_servers
ba_clients
hsm_clients
```

### Step 4: Verify Prerequisites

```bash
# Test connectivity to all hosts
ansible all -i inventory/petascale.ini -m ping

# Verify Python 3.9 on remote hosts (optional pre-check)
ansible all -i inventory/petascale.ini -m raw -a "python3.9 --version"

# Verify BA Client package exists on all remote nodes
ansible all -i inventory/petascale.ini -m stat \
  -a "path=/tmp/8.1.25.0-TIV-TSMBAC-LinuxX86.tar" \
  --become
```

## Running the Playbook

### Basic Installation Execution

```bash
ansible-playbook playbooks/petascale_install.yml \
  -i playbooks/inventory/petascale.ini
```

### Installation with Custom Variables

```bash
# Note: It's recommended to use host_vars files instead of command-line variables
# See CONFIGURATION_GUIDE.md for details

# Override version for all hosts
ansible-playbook playbooks/petascale_install.yml \
  -i playbooks/inventory/petascale.ini \
  -e "ba_client_version=8.1.24.0"

# Use custom variables file
ansible-playbook playbooks/petascale_install.yml \
  -i playbooks/inventory/petascale.ini \
  -e @playbooks/vars/custom_vars.yml
```

### Installation - Limit to Specific Hosts

```bash
# Install only on ba_clients group
ansible-playbook playbooks/petascale_install.yml \
  -i playbooks/inventory/petascale.ini \
  --limit ba_clients

# Install only on specific hosts
ansible-playbook playbooks/petascale_install.yml \
  -i playbooks/inventory/petascale.ini \
  --limit ba-client-01,ba-client-02

# Install only on single host
ansible-playbook playbooks/petascale_install.yml \
  -i playbooks/inventory/petascale.ini \
  --limit ba-client-01
```

### Installation - Dry Run

```bash
# Check what would be installed without actually installing
ansible-playbook playbooks/petascale_install.yml \
  -i playbooks/inventory/petascale.ini \
  --check
```

---

# Uninstallation Guide

## Overview

The `petascale_uninstall.yml` playbook safely removes BA Client software from nodes. It includes safety features and automatic rollback on failure.

## Safety Features

- ⚠️ **Confirmation Required** - Must pass `-e "confirm_uninstall=yes"`
- 🔄 **Automatic Rollback** - Reinstalls packages if uninstall fails
- 💾 **Configuration Backup** - Backs up dsm.opt and dsm.sys files
- 📦 **Package Backup** - Backs up RPMs to /opt/baClientPackagesBk
- ✅ **Data Preservation** - Backed up data on SP Server is NOT deleted

## What Gets Removed

- ✓ BA Client software packages (RPMs)
- ✓ BA Client daemon (stopped)
- ✓ BA Client processes (terminated)

## What Gets Preserved

- ✓ Configuration files (backed up to .bk files)
- ✓ RPM packages (backed up to /opt/baClientPackagesBk)
- ✓ Backed up data on SP Server
- ✓ Node registration on SP Server
- ✓ Backup history on SP Server

## Uninstallation Usage

### Basic Uninstall - All BA Clients

```bash
# Step 1: Review what will be uninstalled (without confirmation)
ansible-playbook playbooks/petascale_uninstall.yml \
  -i playbooks/inventory/petascale.ini

# Step 2: Proceed with uninstall (with confirmation)
ansible-playbook playbooks/petascale_uninstall.yml \
  -i playbooks/inventory/petascale.ini \
  -e "confirm_uninstall=yes"
```

### Uninstall - Specific Hosts Only

```bash
# Uninstall from specific hosts
ansible-playbook playbooks/petascale_uninstall.yml \
  -i playbooks/inventory/petascale.ini \
  -e "confirm_uninstall=yes" \
  --limit ba-client-01,ba-client-02

# Uninstall from single host
ansible-playbook playbooks/petascale_uninstall.yml \
  -i playbooks/inventory/petascale.ini \
  -e "confirm_uninstall=yes" \
  --limit ba-client-01
```

### Uninstall - Dry Run

```bash
# Check what would be uninstalled without actually doing it
ansible-playbook playbooks/petascale_uninstall.yml \
  -i playbooks/inventory/petascale.ini \
  -e "confirm_uninstall=yes" \
  --check
```

### Uninstall - Verbose Output

```bash
# Use -v for detailed progress information
ansible-playbook playbooks/petascale_uninstall.yml \
  -i playbooks/inventory/petascale.ini \
  -e "confirm_uninstall=yes" \
  -v
```

## Post-Uninstall Cleanup (Optional)

After successful uninstall, you may want to:

### 1. Remove Node from SP Server

```bash
# On SP Server, run:
dsmadmc -id=admin -pa=password
remove node <nodename>
```

### 2. Clean Up Backup Directory

```bash
# On each BA client host:
rm -rf /opt/baClientPackagesBk
```

### 3. Remove Configuration Backups

```bash
# On each BA client host:
rm -f /opt/tivoli/tsm/client/ba/bin/dsm.opt.bk
rm -f /opt/tivoli/tsm/client/ba/bin/dsm.sys.bk
```

---

# Configuration Management

## Playbook Execution Flow

1. **Python 3.9 Validation**
   - Checks all nodes for Python 3.9 presence
   - Reports status for each node
   - Fails if Python 3.9 is missing on any node

2. **BA Client Installation**
   - Checks if BA Client is already installed on each node
   - Skips installation if already present (idempotent)
   - For nodes without BA Client:
     - Validates package availability on remote node (fails immediately if not found)
     - Performs system compatibility checks
     - Installs BA Client and dependencies directly from remote node
     - Verifies installation

3. **Installation Summary**
   - Reports which nodes had BA Client already installed
   - Reports which nodes received new installations
   - Reports any installation failures
   - Fails playbook if any installations failed

## Expected Output

### Successful Execution

```
PLAY [Check Python 3.9 presence on all nodes] *********************************

TASK [Check if Python 3.9 is installed] ***************************************
ok: [ba-client-01]
ok: [ba-client-02]

TASK [Report Python 3.9 presence] **********************************************
ok: [ba-client-01] => {
    "msg": "Python 3.9 is PRESENT on ba-client-01 - Version: Python 3.9.16"
}

PLAY [Install BA Client on all nodes] *****************************************

TASK [Check if BA Client is already installed] ********************************
changed: [ba-client-01]
changed: [ba-client-02]

TASK [Display BA Client current status] ***************************************
ok: [ba-client-01] => {
    "msg": "BA Client is NOT installed on ba-client-01 - Will proceed with installation"
}

TASK [Include ba_client_install role] *****************************************
included: /path/to/roles/ba_client_install

[... installation tasks ...]

PLAY [BA Client Installation Summary] *****************************************

TASK [Generate installation summary report] ***********************************
ok: [ba-client-01] => {
    "msg": "============================================================\n
            BA Client Installation Summary\n
            ============================================================\n
            Already Installed (0):\n
            \n
            Newly Installed (2):\n
              - ba-client-01\n
              - ba-client-02\n
            \n
            Failed Installations (0):\n
            ============================================================"
}

PLAY RECAP ********************************************************************
ba-client-01    : ok=25   changed=10   unreachable=0    failed=0
ba-client-02    : ok=25   changed=10   unreachable=0    failed=0
```

## Troubleshooting

### Issue 1: Package Not Found on Remote Node

**Error:**
```
FAILED! => {"msg": "BA Client package not found on ba-client-01! Expected location: /tmp/8.1.25.0-TIV-TSMBAC-LinuxX86.tar"}
```

**Solution:**
```bash
# Copy package to the remote node
scp 8.1.25.0-TIV-TSMBAC-LinuxX86.tar root@ba-client-01:/tmp/

# Or use Ansible to copy to all nodes
ansible all -i inventory/petascale.ini -m copy \
  -a "src=/local/path/8.1.25.0-TIV-TSMBAC-LinuxX86.tar dest=/tmp/ mode=0644" \
  --become

# Verify package is present on all nodes
ansible all -i inventory/petascale.ini -m stat \
  -a "path=/tmp/8.1.25.0-TIV-TSMBAC-LinuxX86.tar" \
  --become
```

### Issue 2: Python 3.9 Not Found

**Error:**
```
FAILED! => {"msg": "Please install Python 3.9 on all missing hosts and re-run the playbook again"}
```

**Solution:**
Install Python 3.9 on the missing hosts before running the playbook.

### Issue 3: Permission Denied

**Error:**
```
FAILED! => {"msg": "Permission denied"}
```

**Solution:**
- Ensure ansible_user has sudo privileges
- Add `become: true` is already set in the playbook
- Verify SSH key authentication is working

### Issue 4: BA Client Already Installed

**Behavior:**
The playbook will skip installation and report the node as "already_installed"

**To Force Reinstall:**
1. Manually uninstall BA Client on the target node
2. Or use the uninstall playbook first
3. Then run the deployment blueprint again

## Advanced Configuration

### Custom Variables File

Create `vars/ba_client_config.yml`:

```yaml
---
ba_client_version: "8.1.25.0"
ba_client_tar_repo: "/opt/ba_client_packages"
ba_client_start_daemon: true
ba_client_extract_dest: "/opt/baClient"
```

Run with:
```bash
ansible-playbook playbooks/petascale_install.yml \
  -i inventory/petascale.ini \
  -e @vars/ba_client_config.yml
```

### Dry Run (Check Mode)

```bash
ansible-playbook playbooks/petascale_install.yml \
  -i inventory/petascale.ini \
  --check
```

Note: Check mode has limitations with the ba_client_install role as it performs actual checks.

## Post-Installation

After successful installation:

1. **Verify Installation:**
   ```bash
   ansible all -i inventory/petascale.ini -m shell -a "rpm -q TIVsm-BA"
   ```

2. **Check BA Client Version:**
   ```bash
   ansible all -i inventory/petascale.ini -m shell -a "dsmc -version"
   ```

3. **Configure BA Client:**
   - Edit `/opt/tivoli/tsm/client/ba/bin/dsm.sys`
   - Edit `/opt/tivoli/tsm/client/ba/bin/dsm.opt`
   - Register node with SP Server

## Support

For issues or questions:
- Check the logs in `/opt/tivoli/tsm/client/ba/bin/dsmerror.log`
- Review Ansible output for detailed error messages
- Consult the BA Client Lifecycle Guide: `docs/guides/ba-client-lifecycle-guide.md`