# Variable Configuration Guide for Install vs Upgrade

This guide explains how to configure variables for installation and upgrade operations, and clarifies which variables control which actions.

---

## Quick Answer

### **You use the SAME host_vars file for both install and upgrade.**

The **playbook you run** determines whether it's an install or upgrade:

```bash
# Install (if not installed)
ansible-playbook playbooks/petascale_install.yml -i playbooks/inventory/petascale.ini

# Upgrade (if already installed)
ansible-playbook playbooks/petascale_upgrade.yml -i playbooks/inventory/petascale.ini -e "confirm_upgrade=yes"
```

---

## Variable Behavior by Component

### BA Client - Simple Approach

#### Single Configuration File

```yaml
# playbooks/host_vars/ba-client-01.yml
# This SAME file is used for BOTH install and upgrade

ba_client_version: "8.2.1.0"              # Target version
ba_client_state: "present"                 # Always "present" for install/upgrade
ba_client_package_path: "/tmp/8.2.1.0-TIV-TSMBAC-LinuxX86.tar"
ba_client_extract_dest: "/opt/baClient"
ba_client_start_daemon: true
```

#### How It Works:

| Current State | Playbook Run | Variable Used | Result |
|---------------|--------------|---------------|--------|
| Not installed | `petascale_install.yml` | `ba_client_version: "8.2.1.0"` | Installs 8.2.1.0 |
| Version 8.1.24.0 | `petascale_upgrade.yml` | `ba_client_version: "8.2.1.0"` | Upgrades to 8.2.1.0 |
| Version 8.2.1.0 | `petascale_upgrade.yml` | `ba_client_version: "8.2.1.0"` | Skips (already at target) |
| Version 8.2.2.0 | `petascale_upgrade.yml` | `ba_client_version: "8.2.1.0"` | **FAILS** (downgrade prevented) |

#### Key Points:

- ✅ **Same variable** for install and upgrade
- ✅ **Same file** for both operations
- ✅ **Playbook determines action** (install vs upgrade)
- ✅ **Role auto-detects** whether upgrade is needed
- ✅ **ba_client_state** is always `"present"` for both install and upgrade

---

### SP Server - State-Based Approach

#### Different States for Different Actions

```yaml
# playbooks/host_vars/sp-server-01.yml
# You CHANGE this file depending on what you want to do

# FOR INSTALLATION:
sp_server_version: "8.2.2.000"
sp_server_state: "present"      # State: present = install
sp_server_action: "install"     # Action: install

# FOR UPGRADE (change the same file):
sp_server_version: "8.2.2.000"
sp_server_state: "upgrade"      # State: upgrade = upgrade
sp_server_action: "upgrade"     # Action: upgrade
```

#### How It Works:

| Current State | Variables Set | Playbook Run | Result |
|---------------|---------------|--------------|--------|
| Not installed | `state: "present"`, `action: "install"` | `petascale_install.yml` | Installs 8.2.2.0 |
| Version 8.1.24.0 | `state: "upgrade"`, `action: "upgrade"` | `petascale_upgrade.yml` | Upgrades to 8.2.2.0 |
| Version 8.2.2.0 | `state: "upgrade"`, `action: "upgrade"` | `petascale_upgrade.yml` | Skips (already at target) |
| Version 8.2.3.0 | `state: "upgrade"`, `action: "upgrade"` | `petascale_upgrade.yml` | **FAILS** (downgrade prevented) |

#### Key Points:

- ⚠️  **Must change state and action** for upgrade
- ⚠️  **Same file**, but different values
- ✅ **sp_server_version** is the target version for both
- ✅ **Playbook checks state/action** to determine operation

---

## Recommended Workflow

### Option 1: Keep Separate Example Files (Recommended)

Maintain separate example files for clarity:

```
playbooks/host_vars/
├── ba-client-01.yml                      # Active config (for install)
├── ba-client-01-upgrade-example.yml      # Reference for upgrade
├── sp-server-01.yml                      # Active config (for install)
└── sp-server-01-upgrade-example.yml      # Reference for upgrade
```

**When you need to upgrade:**

```bash
# Step 1: Update the active file with upgrade settings
cp playbooks/host_vars/sp-server-01-upgrade-example.yml \
   playbooks/host_vars/sp-server-01.yml

# Step 2: Edit to set correct version
vi playbooks/host_vars/sp-server-01.yml

# Step 3: Run upgrade
ansible-playbook playbooks/petascale_upgrade.yml \
  -i playbooks/inventory/petascale.ini \
  -e "confirm_upgrade=yes"
```

---

### Option 2: Modify Active File Directly

Simply edit the active file when you need to upgrade:

```bash
# Edit the file
vi playbooks/host_vars/sp-server-01.yml

# Change:
# sp_server_state: "present"   → sp_server_state: "upgrade"
# sp_server_action: "install"  → sp_server_action: "upgrade"
# sp_server_version: "8.1.24.0" → sp_server_version: "8.2.2.0"

# Run upgrade
ansible-playbook playbooks/petascale_upgrade.yml \
  -i playbooks/inventory/petascale.ini \
  -e "confirm_upgrade=yes"
```

---

## Detailed Configuration Examples

### BA Client Configuration

#### For Both Install and Upgrade (Same File):

```yaml
---
# playbooks/host_vars/ba-client-01.yml
# This file works for BOTH install and upgrade

# Target version (used by both install and upgrade playbooks)
ba_client_version: "8.2.1.0"

# State is always "present" for install/upgrade
ba_client_state: "present"

# Package location (update this when changing version)
ba_client_package_path: "/tmp/8.2.1.0-TIV-TSMBAC-LinuxX86.tar"

# Installation directory
ba_client_extract_dest: "/opt/baClient"

# Service configuration
ba_client_start_daemon: true

# OS type
os_type: "LinuxX86"
```

**To upgrade to a new version:**

1. Update `ba_client_version` to new version (e.g., "8.2.2.0")
2. Update `ba_client_package_path` to point to new package
3. Ensure new package is on remote node
4. Run `petascale_upgrade.yml`

---

### SP Server Configuration

#### For Installation:

```yaml
---
# playbooks/host_vars/sp-server-01.yml
# Configuration for INSTALLATION

# Target version
sp_server_version: "8.2.2.000"

# State and action for INSTALL
sp_server_state: "present"
sp_server_action: "install"

# Package location
sp_server_bin_repo: "/tmp"

# Installation directories
sp_server_install_dest: "/opt/sp_server_binary/"

# Server configuration
server_name: "PETASCALE-SP01"
server_password: "IBMSPServer@@123456789"

# ... other settings ...
```

#### For Upgrade (Modify Same File):

```yaml
---
# playbooks/host_vars/sp-server-01.yml
# Configuration for UPGRADE (modified)

# Target version (NEW VERSION)
sp_server_version: "8.2.3.000"

# State and action for UPGRADE (CHANGED)
sp_server_state: "upgrade"
sp_server_action: "upgrade"

# Package location (ensure new package is here)
sp_server_bin_repo: "/tmp"

# Installation directories (same)
sp_server_install_dest: "/opt/sp_server_binary/"
sp_server_upgrade_dest: "/opt/sp_server_upgrade_binary"

# Server configuration (same)
server_name: "PETASCALE-SP01"
server_password: "IBMSPServer@@123456789"

# ... other settings (same) ...
```

---

## Version Variable Summary

### BA Client

| Variable | Install Value | Upgrade Value | Notes |
|----------|---------------|---------------|-------|
| `ba_client_version` | `"8.2.1.0"` | `"8.2.2.0"` | Target version (change for upgrade) |
| `ba_client_state` | `"present"` | `"present"` | Always "present" |
| `ba_client_package_path` | Path to package | Path to NEW package | Update for new version |

**Key Point:** Only `ba_client_version` and `ba_client_package_path` change for upgrade.

---

### SP Server

| Variable | Install Value | Upgrade Value | Notes |
|----------|---------------|---------------|-------|
| `sp_server_version` | `"8.2.2.000"` | `"8.2.3.000"` | Target version (change for upgrade) |
| `sp_server_state` | `"present"` | `"upgrade"` | **MUST CHANGE** for upgrade |
| `sp_server_action` | `"install"` | `"upgrade"` | **MUST CHANGE** for upgrade |
| `sp_server_bin_repo` | Path to package | Path to NEW package | Update for new version |

**Key Point:** Must change `state`, `action`, `version`, and `bin_repo` for upgrade.

---

## Common Questions

### Q: Do I need separate files for install and upgrade?

**A: No, but it's helpful for reference.**

- **BA Client:** Same file works for both (just update version)
- **SP Server:** Same file, but must change state/action values

**Recommendation:** Keep `-upgrade-example.yml` files as templates, modify active files as needed.

---

### Q: What if I forget to change sp_server_state to "upgrade"?

**A: The install playbook will skip it (already installed), upgrade playbook will fail.**

```bash
# If you run install playbook with state="present" on installed host:
# Result: Skips (already installed)

# If you run upgrade playbook with state="present":
# Result: May not work as expected
```

**Solution:** Always set `sp_server_state: "upgrade"` and `sp_server_action: "upgrade"` for upgrades.

---

### Q: Can I use the same version number for install and upgrade?

**A: Yes, but upgrade will skip if already at that version.**

```yaml
# Current: 8.2.1.0 installed
# Config: ba_client_version: "8.2.1.0"
# Run: petascale_upgrade.yml
# Result: Skips (already at target version)
```

---

### Q: How do I know which playbook to run?

**A: Check current installation status first.**

```bash
# Check if installed
ansible ba_clients -i playbooks/inventory/petascale.ini \
  -m shell -a "rpm -q TIVsm-BA || echo 'Not installed'" --become

# If "Not installed" → Use petascale_install.yml
# If version shown → Use petascale_upgrade.yml (if upgrading)
```

---

## Best Practices

### 1. Version Control Your Config Files

```bash
# Before making changes
git add playbooks/host_vars/
git commit -m "Pre-upgrade config snapshot"

# Make changes for upgrade
vi playbooks/host_vars/sp-server-01.yml

# Commit upgrade config
git add playbooks/host_vars/
git commit -m "Updated sp-server-01 for upgrade to 8.2.3.0"
```

### 2. Document Version Changes

```yaml
# playbooks/host_vars/sp-server-01.yml
---
# Version History:
# - 2026-01-15: Installed 8.2.1.0
# - 2026-03-20: Upgraded to 8.2.2.0
# - 2026-05-04: Upgrading to 8.2.3.0

sp_server_version: "8.2.3.000"
sp_server_state: "upgrade"
sp_server_action: "upgrade"
```

### 3. Use Example Files as Templates

```bash
# Keep example files as reference
ls playbooks/host_vars/*-example.yml

# Copy and modify for your needs
cp playbooks/host_vars/sp-server-01-upgrade-example.yml \
   playbooks/host_vars/sp-server-01.yml
```

### 4. Verify Before Running

```bash
# Check current version
ansible sp_servers -i playbooks/inventory/petascale.ini \
  -m shell -a "/opt/IBM/InstallationManager/eclipse/tools/imcl listInstalledPackages | grep dsm.server" --become

# Check target version in config
grep sp_server_version playbooks/host_vars/sp-server-01.yml

# Verify target > current before running upgrade
```

---

## Summary

| Component | Same File? | What Changes for Upgrade? | Key Variable |
|-----------|------------|---------------------------|--------------|
| **BA Client** | ✅ Yes | Only version and package path | `ba_client_version` |
| **SP Server** | ✅ Yes | Version, state, action, package path | `sp_server_state`, `sp_server_action` |

**Key Takeaway:** You use the same host_vars file for both install and upgrade, but:
- **BA Client:** Just update the version
- **SP Server:** Must also change state and action

---

## Related Documentation

- **Upgrade Playbook:** `playbooks/petascale_upgrade.yml`
- **Upgrade Behavior Guide:** `playbooks/UPGRADE_BEHAVIOR_GUIDE.md`
- **Version Check Guide:** `playbooks/VERSION_CHECK_GUIDE.md`
- **Configuration Guide:** `playbooks/CONFIGURATION_GUIDE.md`

---

**Last Updated:** 2026-05-04  
**Maintained by:** IBM Storage Protect Ansible Team