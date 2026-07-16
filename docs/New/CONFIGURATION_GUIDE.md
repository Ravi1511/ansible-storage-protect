# Petascale Installation & Uninstallation - Customer Configuration Guide

This guide explains how to configure the petascale installation and uninstallation playbooks for your environment. The configuration uses Ansible's standard variable precedence system, allowing you to customize settings globally, per-group, or per-host.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Configuration File Structure](#configuration-file-structure)
3. [Variable Precedence](#variable-precedence)
4. [Configuring BA Clients](#configuring-ba-clients)
5. [Installation Examples](#installation-examples)
6. [Uninstallation Guide](#uninstallation-guide)
7. [Troubleshooting](#troubleshooting)

---

## Quick Start

### Step 1: Copy and Configure Inventory

```bash
cd playbooks/inventory
cp petascale.ini.example petascale.ini
```

Edit `petascale.ini` and configure your hosts:

```ini
[ba_clients]
ba-client-01 ansible_host=192.168.2.10 ansible_user=root
ba-client-02 ansible_host=192.168.2.11 ansible_user=root
ba-client-03 ansible_host=192.168.2.12 ansible_user=root
```

### Step 2: Configure Per-Host Variables

For each BA client, edit or create a host_vars file:

```bash
# Edit configuration for ba-client-01
vi playbooks/host_vars/ba-client-01.yml
```

### Step 3: Run the Installation Playbook

```bash
ansible-playbook playbooks/petascale_install.yml \
  -i playbooks/inventory/petascale.ini
```

### Step 4: (Optional) Uninstall BA Client

```bash
ansible-playbook playbooks/petascale_uninstall.yml \
  -i playbooks/inventory/petascale.ini \
  -e "confirm_uninstall=yes"
```

---

## Configuration File Structure

```
playbooks/
├── petascale_install.yml           # Installation playbook (DO NOT EDIT)
├── petascale_uninstall.yml         # Uninstallation playbook (DO NOT EDIT)
├── CONFIGURATION_GUIDE.md          # This guide
├── inventory/
│   └── petascale.ini               # Your inventory file (EDIT THIS)
├── group_vars/
│   ├── all.yml                     # Global defaults (EDIT THIS)
│   └── ba_clients.yml              # BA client group defaults (EDIT THIS)
└── host_vars/
    ├── ba-client-01.yml            # Per-host config (EDIT THIS)
    ├── ba-client-02.yml            # Per-host config (EDIT THIS)
    └── ba-client-03.yml            # Per-host config (EDIT THIS)
```

---

## Variable Precedence

Variables are loaded in the following order (highest to lowest priority):

1. **host_vars/\<hostname\>.yml** (HIGHEST PRIORITY)
   - Per-host customization
   - Overrides all other settings
   - Example: `playbooks/host_vars/ba-client-01.yml`

2. **group_vars/\<groupname\>.yml**
   - Group-specific settings
   - Example: `playbooks/group_vars/ba_clients.yml`

3. **group_vars/all.yml**
   - Global defaults for all hosts
   - Example: `playbooks/group_vars/all.yml`

4. **Playbook defaults** (LOWEST PRIORITY)
   - Built-in defaults in the playbook

### Example: Variable Override

If you set `ba_client_version` in multiple places:

```yaml
# group_vars/all.yml
ba_client_version: "8.2.1.0"

# group_vars/ba_clients.yml
ba_client_version: "8.1.24.0"

# host_vars/ba-client-01.yml
ba_client_version: "8.2.1.0"
```

Result: `ba-client-01` will use version **8.2.1.0** (from host_vars, highest priority)

---

## Configuring BA Clients

### Scenario 1: All BA Clients Use Same Version

**Configuration:**
- Set version in `group_vars/ba_clients.yml`
- No need for host_vars files

**File: playbooks/group_vars/ba_clients.yml**
```yaml
---
ba_client_version: "8.2.1.0"
os_type: "LinuxX86"
ba_client_package_path: "/tmp/8.2.1.0-TIV-TSMBAC-LinuxX86.tar"
ba_client_start_daemon: false
```

### Scenario 2: Each BA Client Uses Different Version

**Configuration:**
- Create separate host_vars file for each client
- Each file specifies its own version

**File: playbooks/host_vars/ba-client-01.yml**
```yaml
---
ba_client_version: "8.2.1.0"
os_type: "LinuxX86"
ba_client_package_path: "/tmp/8.2.1.0-TIV-TSMBAC-LinuxX86.tar"
ba_client_start_daemon: false
```

**File: playbooks/host_vars/ba-client-02.yml**
```yaml
---
ba_client_version: "8.1.24.0"
os_type: "LinuxX86"
ba_client_package_path: "/tmp/8.1.24.0-TIV-TSMBAC-LinuxX86.tar"
ba_client_start_daemon: true
```

**File: playbooks/host_vars/ba-client-03.yml**
```yaml
---
ba_client_version: "8.2.1.0"
os_type: "LinuxX86_64"
ba_client_package_path: "/opt/software/8.2.1.0-TIV-TSMBAC-LinuxX86_64.tar"
ba_client_start_daemon: false
```

### Scenario 3: Mixed Configuration (Some Same, Some Different)

**Configuration:**
- Set common version in `group_vars/ba_clients.yml`
- Override only for specific hosts in their host_vars files

**File: playbooks/group_vars/ba_clients.yml**
```yaml
---
# Default for all BA clients
ba_client_version: "8.2.1.0"
os_type: "LinuxX86"
ba_client_package_path: "/tmp/{{ ba_client_version }}-TIV-TSMBAC-{{ os_type }}.tar"
ba_client_start_daemon: false
```

**File: playbooks/host_vars/ba-client-02.yml** (only for the one that's different)
```yaml
---
# Override only for ba-client-02
ba_client_version: "8.1.24.0"
ba_client_package_path: "/tmp/8.1.24.0-TIV-TSMBAC-LinuxX86.tar"
# Other settings inherited from group_vars
```

---

## Installation Examples

### Installation Example 1: Installing 3 BA Clients with Different Versions

**Step 1: Configure Inventory**

```ini
# playbooks/inventory/petascale.ini
[ba_clients]
ba-client-01 ansible_host=10.0.1.10 ansible_user=root
ba-client-02 ansible_host=10.0.1.11 ansible_user=root
ba-client-03 ansible_host=10.0.1.12 ansible_user=root
```

**Step 2: Configure Each Host**

```yaml
# playbooks/host_vars/ba-client-01.yml
---
ba_client_version: "8.2.1.0"
os_type: "LinuxX86"
ba_client_package_path: "/tmp/8.2.1.0-TIV-TSMBAC-LinuxX86.tar"
ba_client_start_daemon: false
```

```yaml
# playbooks/host_vars/ba-client-02.yml
---
ba_client_version: "8.1.24.0"
os_type: "LinuxX86"
ba_client_package_path: "/tmp/8.1.24.0-TIV-TSMBAC-LinuxX86.tar"
ba_client_start_daemon: true
```

```yaml
# playbooks/host_vars/ba-client-03.yml
---
ba_client_version: "8.2.1.0"
os_type: "LinuxX86_64"
ba_client_package_path: "/opt/software/8.2.1.0-TIV-TSMBAC-LinuxX86_64.tar"
ba_client_start_daemon: false
```

**Step 3: Run Playbook**

```bash
ansible-playbook playbooks/petascale_install.yml \
  -i playbooks/inventory/petascale.ini
```

### Installation Example 2: Installing Only Specific BA Clients

```bash
# Install only ba-client-01 and ba-client-02
ansible-playbook playbooks/petascale_install.yml \
  -i playbooks/inventory/petascale.ini \
  --limit ba-client-01,ba-client-02

# Install only ba-client-03
ansible-playbook playbooks/petascale_install.yml \
  -i playbooks/inventory/petascale.ini \
  --limit ba-client-03
```

### Installation Example 3: Custom Package Locations

If your packages are in different locations on each node:

```yaml
# playbooks/host_vars/ba-client-01.yml
---
ba_client_version: "8.2.1.0"
os_type: "LinuxX86"
ba_client_package_path: "/mnt/nfs/software/8.2.1.0-TIV-TSMBAC-LinuxX86.tar"
```

```yaml
# playbooks/host_vars/ba-client-02.yml
---
ba_client_version: "8.2.1.0"
os_type: "LinuxX86"
ba_client_package_path: "/opt/downloads/8.2.1.0-TIV-TSMBAC-LinuxX86.tar"
```

---

## Uninstallation Guide

### Overview

The `petascale_uninstall.yml` playbook safely removes BA Client software from nodes listed in your inventory. It includes safety features like confirmation prompts, automatic rollback on failure, and configuration backups.

### Safety Features

1. **Confirmation Required** - Must explicitly pass `-e "confirm_uninstall=yes"`
2. **Automatic Rollback** - If uninstall fails, previously removed packages are reinstalled
3. **Configuration Backup** - dsm.opt and dsm.sys files are backed up to .bk files
4. **Package Backup** - RPM packages are backed up to /opt/baClientPackagesBk
5. **Data Preservation** - Backed up data on SP Server is NOT deleted

### What Gets Removed

- ✓ BA Client software packages (RPMs)
- ✓ BA Client daemon (stopped)
- ✓ BA Client processes (terminated)

### What Gets Preserved

- ✓ Configuration files (backed up to .bk files)
- ✓ RPM packages (backed up to /opt/baClientPackagesBk)
- ✓ Backed up data on SP Server
- ✓ Node registration on SP Server
- ✓ Backup history on SP Server

### Basic Uninstall Usage

#### Uninstall from All BA Clients

```bash
ansible-playbook playbooks/petascale_uninstall.yml \
  -i playbooks/inventory/petascale.ini \
  -e "confirm_uninstall=yes"
```

#### Uninstall from Specific Hosts

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

#### Dry Run (Check Mode)

```bash
# See what would be uninstalled without actually doing it
ansible-playbook playbooks/petascale_uninstall.yml \
  -i playbooks/inventory/petascale.ini \
  -e "confirm_uninstall=yes" \
  --check
```

### Uninstall Examples

#### Example 1: Uninstall from All BA Clients

```bash
# Step 1: Review what will be uninstalled (without confirmation)
ansible-playbook playbooks/petascale_uninstall.yml \
  -i playbooks/inventory/petascale.ini

# Output will show warning and list of hosts, then stop

# Step 2: Proceed with uninstall (with confirmation)
ansible-playbook playbooks/petascale_uninstall.yml \
  -i playbooks/inventory/petascale.ini \
  -e "confirm_uninstall=yes"
```

#### Example 2: Uninstall from Specific Hosts Only

```bash
# Uninstall only from ba-client-02 and ba-client-03
ansible-playbook playbooks/petascale_uninstall.yml \
  -i playbooks/inventory/petascale.ini \
  -e "confirm_uninstall=yes" \
  --limit ba-client-02,ba-client-03
```

#### Example 3: Uninstall with Verbose Output

```bash
# Use -v for verbose output to see detailed progress
ansible-playbook playbooks/petascale_uninstall.yml \
  -i playbooks/inventory/petascale.ini \
  -e "confirm_uninstall=yes" \
  -v
```

### Uninstall Process Flow

1. **Display Warning** - Shows what will be uninstalled
2. **Check Confirmation** - Requires `-e "confirm_uninstall=yes"`
3. **Python Check** - Verifies Python 3.9 is available
4. **Pre-Uninstall Checks** - Checks if BA Client is installed
5. **Display Summary** - Shows which hosts will be affected
6. **Stop Processes** - Stops BA Client daemon and processes
7. **Backup Files** - Backs up configuration and packages
8. **Uninstall Packages** - Removes RPMs in dependency order
9. **Verify Uninstall** - Confirms BA Client is removed
10. **Display Report** - Shows success/failure summary

### Rollback on Failure

If uninstallation fails:
1. Previously uninstalled packages are automatically reinstalled
2. System is restored to pre-uninstall state
3. Configuration backups remain in place
4. Error message shows which package failed and why

### Post-Uninstall Cleanup

After successful uninstall, you may want to:

1. **Remove Node from SP Server** (optional):
   ```bash
   # On SP Server, run:
   dsmadmc -id=admin -pa=password
   remove node <nodename>
   ```

2. **Clean Up Backup Directory** (optional):
   ```bash
   # On each BA client host:
   rm -rf /opt/baClientPackagesBk
   ```

3. **Remove Configuration Backups** (optional):
   ```bash
   # On each BA client host:
   rm -f /opt/tivoli/tsm/client/ba/bin/dsm.opt.bk
   rm -f /opt/tivoli/tsm/client/ba/bin/dsm.sys.bk
   ```

### Troubleshooting Uninstall

#### Issue: "Confirmation Required" Error

**Problem:** Playbook stops with "UNINSTALL CANCELLED - Confirmation Required"

**Solution:** Add the confirmation parameter:
```bash
ansible-playbook playbooks/petascale_uninstall.yml \
  -i playbooks/inventory/petascale.ini \
  -e "confirm_uninstall=yes"
```

#### Issue: Uninstall Fails with Dependency Error

**Problem:** Package uninstall fails due to dependencies

**Solution:**
- The playbook automatically rolls back
- Check which package failed in the error message
- Manually stop any running BA Client processes
- Retry the uninstall

#### Issue: BA Client Not Installed

**Problem:** Playbook reports "BA Client is not installed"

**Solution:** This is normal if BA Client was already removed. The playbook will skip that host.

#### Issue: Cannot Connect to Host

**Problem:** "Failed to connect to host"

**Solution:**
1. Verify host is reachable: `ping <hostname>`
2. Test SSH: `ssh root@<hostname>`
3. Check inventory file has correct ansible_host
4. Verify ansible_user is correct

---

## Required Variables Per Host

Each BA client host **MUST** have the following variables defined (either in host_vars or group_vars):

| Variable | Description | Example |
|----------|-------------|---------|
| `ba_client_version` | BA Client version to install | `"8.2.1.0"` |
| `os_type` | Operating system type | `"LinuxX86"` or `"LinuxX86_64"` |
| `ba_client_package_path` | Full path to package on remote node | `"/tmp/8.2.1.0-TIV-TSMBAC-LinuxX86.tar"` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ba_client_state` | Install or uninstall | `"present"` |
| `ba_client_extract_dest` | Installation directory | `"/opt/baClient"` |
| `ba_client_temp_dest` | Temporary directory | `"/tmp/"` |
| `ba_client_start_daemon` | Auto-start daemon | `false` |

---

## Troubleshooting

### Issue: "Variable not defined" Error

**Problem:** Playbook fails with "ba_client_version is not defined"

**Solution:** Ensure the variable is set in one of these files:
1. `playbooks/host_vars/<hostname>.yml`
2. `playbooks/group_vars/ba_clients.yml`
3. `playbooks/group_vars/all.yml`

### Issue: Wrong Version Being Installed

**Problem:** BA client installs different version than expected

**Solution:** Check variable precedence. Host_vars overrides group_vars. Use:

```bash
ansible-inventory -i playbooks/inventory/petascale.ini \
  --host ba-client-01 --yaml
```

This shows all variables for the host and their sources.

### Issue: Package Not Found

**Problem:** "BA Client package not found on remote node"

**Solution:** 
1. Verify the package exists on the remote node at the specified path
2. Check the `ba_client_package_path` variable in host_vars
3. Ensure the filename matches the pattern: `<version>-TIV-TSMBAC-<os_type>.tar`

### Issue: Cannot Connect to Host

**Problem:** "Failed to connect to host"

**Solution:**
1. Verify `ansible_host` in inventory is correct
2. Test SSH connection: `ssh root@<ansible_host>`
3. Check `ansible_user` is correct
4. Verify Python 3.9+ is installed on remote node

---

## Best Practices

1. **Use host_vars for per-host customization**
   - Each BA client can have its own version and settings
   - Easy to manage and version control

2. **Use group_vars for common settings**
   - Set defaults that apply to all BA clients
   - Reduces duplication

3. **Keep inventory file clean**
   - Only host definitions and connection parameters
   - Move complex variables to host_vars/group_vars

4. **Version control your configuration**
   - Commit host_vars and group_vars to git
   - Track changes over time

5. **Test with --check mode first**
   ```bash
   ansible-playbook playbooks/petascale_install.yml \
     -i playbooks/inventory/petascale.ini \
     --check
   ```

6. **Use --limit for testing**
   ```bash
   # Test on one host first
   ansible-playbook playbooks/petascale_install.yml \
     -i playbooks/inventory/petascale.ini \
     --limit ba-client-01
   ```

---

## Additional Resources

- **Ansible Variable Precedence:** https://docs.ansible.com/ansible/latest/user_guide/playbooks_variables.html#variable-precedence-where-should-i-put-a-variable
- **Ansible Inventory:** https://docs.ansible.com/ansible/latest/user_guide/intro_inventory.html
- **IBM Storage Protect Documentation:** https://www.ibm.com/docs/en/storage-protect

---

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review example host_vars files in `playbooks/host_vars/`
3. Consult the main README: `playbooks/PETASCALE_DEPLOYMENT_README.md`