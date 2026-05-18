# Upgrade Playbook Behavior Guide

This guide explains how the `petascale_upgrade.yml` playbook behaves in different scenarios, particularly when software is not installed.

---

## What Happens When Software Is Not Installed?

### TL;DR - Safe Behavior

**The upgrade playbook will SKIP hosts where software is not installed and continue with other hosts.**

- ✅ **No errors** - Playbook completes successfully
- ✅ **Clear reporting** - Shows which hosts were skipped
- ✅ **No changes** - Skipped hosts remain unchanged
- ✅ **Other hosts proceed** - Installed hosts are upgraded normally

---

## Detailed Behavior by Component

### SP Server - Not Installed Scenario

#### What Happens:

1. **Detection Phase** (Play 4):
   ```
   ✓ Checks if SP Server is installed using imcl
   ✓ Sets sp_server_installed: false
   ✓ Sets sp_server_current_version: "Not installed"
   ```

2. **Version Validation Phase** (Play 6):
   ```
   ✓ Skips version comparison (only runs when sp_server_installed: true)
   ✓ No downgrade check performed
   ✓ No errors generated
   ```

3. **Upgrade Phase** (Play 7):
   ```
   ✓ Displays: "SP Server is not installed on <hostname>. Skipping upgrade."
   ✓ Does NOT run sp_server_install role
   ✓ Does NOT attempt any installation
   ✓ Sets sp_server_upgrade_status: "not_installed"
   ```

4. **Summary Report** (Play 8):
   ```
   ✓ Lists host under "Not Installed" category
   ✓ Shows: "ℹ️  INFO: No SP Servers were upgraded - All specified hosts did not have SP Server installed"
   ✓ Playbook continues (does not fail)
   ```

#### Example Output:

```
TASK [Skip upgrade if SP Server is not installed]
ok: [sp-server-01] => {
    "msg": "SP Server is not installed on sp-server-01. Skipping upgrade."
}

============================================================
SP SERVER UPGRADE SUMMARY REPORT
============================================================

Not Installed (1):
  - sp-server-01

Successfully Upgraded (0):

Failed Upgrades (0):

ℹ️  INFO: No SP Servers were upgraded
- All specified hosts did not have SP Server installed
============================================================
```

---

### BA Client - Not Installed Scenario

#### What Happens:

1. **Detection Phase** (Play 5):
   ```
   ✓ Checks if BA Client is installed using rpm -q TIVsm-BA
   ✓ Sets ba_client_installed: false
   ✓ Sets ba_client_current_version: "Not installed"
   ```

2. **Version Validation Phase** (Play 6):
   ```
   ✓ Skips version comparison (only runs when ba_client_installed: true)
   ✓ No downgrade check performed
   ✓ No errors generated
   ```

3. **Upgrade Phase** (Play 9):
   ```
   ✓ Displays: "BA Client is not installed on <hostname>. Skipping upgrade."
   ✓ Does NOT run ba_client_install role
   ✓ Does NOT attempt any installation
   ✓ Sets ba_client_upgrade_status: "not_installed"
   ```

4. **Summary Report** (Play 10):
   ```
   ✓ Lists host under "Not Installed" category
   ✓ Shows: "ℹ️  INFO: No BA Clients were upgraded - All specified hosts did not have BA Client installed"
   ✓ Playbook continues (does not fail)
   ```

#### Example Output:

```
TASK [Skip upgrade if BA Client is not installed]
ok: [ba-client-01] => {
    "msg": "BA Client is not installed on ba-client-01. Skipping upgrade."
}

============================================================
BA CLIENT UPGRADE SUMMARY REPORT
============================================================

Not Installed (1):
  - ba-client-01: BA Client was not installed

Successfully Upgraded (0):

Failed Upgrades (0):

ℹ️  INFO: No BA Clients were upgraded
- All specified hosts did not have BA Client installed
============================================================
```

---

## Mixed Environment Scenarios

### Scenario 1: Some Hosts Installed, Some Not

**Setup:**
- sp-server-01: SP Server 8.1.24.0 installed
- sp-server-02: SP Server NOT installed
- sp-server-03: SP Server 8.2.1.0 installed

**Result:**
```
SP SERVER UPGRADE SUMMARY REPORT
============================================================

Not Installed (1):
  - sp-server-02

Successfully Upgraded (1):
  - sp-server-01: 8.1.24.0 → 8.2.2.0

Failed Upgrades (0):

Already at Target Version (1):
  - sp-server-03: Already running 8.2.1.0 (target: 8.2.2.0)
============================================================
```

**Outcome:**
- ✅ sp-server-01: Upgraded successfully
- ⏭️  sp-server-02: Skipped (not installed)
- ✅ sp-server-03: Upgraded successfully
- ✅ Playbook completes successfully

---

### Scenario 2: All Hosts Not Installed

**Setup:**
- All hosts in ba_clients group have no BA Client installed

**Result:**
```
BA CLIENT UPGRADE SUMMARY REPORT
============================================================

Not Installed (3):
  - ba-client-01: BA Client was not installed
  - ba-client-02: BA Client was not installed
  - ba-client-03: BA Client was not installed

Successfully Upgraded (0):

Failed Upgrades (0):

ℹ️  INFO: No BA Clients were upgraded
- All specified hosts did not have BA Client installed
============================================================
```

**Outcome:**
- ⏭️  All hosts skipped
- ✅ Playbook completes successfully
- ℹ️  Informational message displayed

---

## Why This Behavior?

### Design Rationale

1. **Safety First**: Upgrade playbook should only upgrade, not install
2. **Clear Intent**: Use `petascale_install.yml` for fresh installations
3. **Graceful Handling**: Don't fail the entire playbook if some hosts aren't ready
4. **Flexibility**: Allows running upgrade across mixed environments
5. **Clear Reporting**: Users know exactly what happened on each host

### Separation of Concerns

| Playbook | Purpose | Behavior When Not Installed |
|----------|---------|----------------------------|
| `petascale_install.yml` | Fresh installation | Installs software |
| `petascale_upgrade.yml` | Upgrade existing | Skips (no action) |
| `petascale_uninstall.yml` | Remove software | Skips (no action) |

---

## When to Use Which Playbook

### Use `petascale_install.yml` When:
- ✅ Software is NOT installed
- ✅ You want to perform fresh installation
- ✅ You're setting up new hosts

### Use `petascale_upgrade.yml` When:
- ✅ Software IS already installed
- ✅ You want to upgrade to a newer version
- ✅ You have a mixed environment (some installed, some not)

### Use `petascale_uninstall.yml` When:
- ✅ Software IS installed
- ✅ You want to remove the software
- ✅ You're decommissioning hosts

---

## Common Questions

### Q: Can I use upgrade playbook to install software on new hosts?

**A: No.** The upgrade playbook will skip hosts where software is not installed.

**Solution:** Use `petascale_install.yml` for fresh installations.

```bash
# For new installations
ansible-playbook playbooks/petascale_install.yml \
  -i playbooks/inventory/petascale.ini

# For upgrades
ansible-playbook playbooks/petascale_upgrade.yml \
  -i playbooks/inventory/petascale.ini \
  -e "confirm_upgrade=yes"
```

---

### Q: What if I accidentally run upgrade on hosts without software?

**A: No problem!** The playbook will:
- ✅ Detect software is not installed
- ✅ Skip those hosts gracefully
- ✅ Report them in the "Not Installed" category
- ✅ Continue with other hosts that have software installed
- ✅ Complete successfully

**No harm done!**

---

### Q: Can I run upgrade on a mixed environment?

**A: Yes!** The playbook handles mixed environments gracefully:

```bash
# This works fine even if some hosts don't have software installed
ansible-playbook playbooks/petascale_upgrade.yml \
  -i playbooks/inventory/petascale.ini \
  -e "confirm_upgrade=yes"
```

**Result:**
- Hosts with software: Upgraded
- Hosts without software: Skipped
- Playbook: Completes successfully

---

### Q: How do I know which hosts were skipped?

**A: Check the summary reports.** The playbook provides detailed reports:

```
SP SERVER UPGRADE SUMMARY REPORT
============================================================

Not Installed (2):
  - sp-server-02
  - sp-server-04

Successfully Upgraded (3):
  - sp-server-01: 8.1.24.0 → 8.2.2.0
  - sp-server-03: 8.1.25.0 → 8.2.2.0
  - sp-server-05: 8.2.0.0 → 8.2.2.0
============================================================
```

---

### Q: Will the playbook fail if no hosts have software installed?

**A: No.** The playbook will:
- ✅ Complete successfully
- ✅ Show all hosts in "Not Installed" category
- ℹ️  Display informational message
- ✅ Exit with success status

This allows you to run the playbook across your entire inventory without errors.

---

## Best Practices

### 1. Check Installation Status First

Before running upgrade, verify what's installed:

```bash
# Check SP Server versions
ansible sp_servers -i playbooks/inventory/petascale.ini \
  -m shell \
  -a "/opt/IBM/InstallationManager/eclipse/tools/imcl listInstalledPackages | grep dsm.server || echo 'Not installed'" \
  --become

# Check BA Client versions
ansible ba_clients -i playbooks/inventory/petascale.ini \
  -m shell \
  -a "rpm -q TIVsm-BA || echo 'Not installed'" \
  --become
```

### 2. Use Appropriate Playbook

```bash
# For hosts WITHOUT software → Use install playbook
ansible-playbook playbooks/petascale_install.yml \
  -i playbooks/inventory/petascale.ini \
  --limit "hosts-without-software"

# For hosts WITH software → Use upgrade playbook
ansible-playbook playbooks/petascale_upgrade.yml \
  -i playbooks/inventory/petascale.ini \
  -e "confirm_upgrade=yes" \
  --limit "hosts-with-software"
```

### 3. Review Summary Reports

Always review the summary reports to understand what happened:
- **Not Installed**: Hosts that were skipped
- **Successfully Upgraded**: Hosts that were upgraded
- **Failed Upgrades**: Hosts where upgrade failed

### 4. Mixed Environment Strategy

For mixed environments:

```bash
# Step 1: Run upgrade (will skip non-installed hosts)
ansible-playbook playbooks/petascale_upgrade.yml \
  -i playbooks/inventory/petascale.ini \
  -e "confirm_upgrade=yes"

# Step 2: Note which hosts were skipped (from summary report)

# Step 3: Install on skipped hosts
ansible-playbook playbooks/petascale_install.yml \
  -i playbooks/inventory/petascale.ini \
  --limit "skipped-host-01,skipped-host-02"
```

---

## Summary

| Scenario | Upgrade Playbook Behavior | Outcome |
|----------|---------------------------|---------|
| Software installed | Upgrades to new version | ✅ Success |
| Software not installed | Skips host gracefully | ✅ Success (no action) |
| Mixed environment | Upgrades installed, skips others | ✅ Success (partial) |
| All hosts not installed | Skips all hosts | ✅ Success (no action) |
| Downgrade attempted | Fails with error message | ❌ Fails (by design) |

**Key Takeaway:** The upgrade playbook is safe to run even on hosts without software installed. It will gracefully skip them and continue with other hosts.

---

## Related Documentation

- **Installation Guide:** `playbooks/PETASCALE_DEPLOYMENT_README.md`
- **Version Check Guide:** `playbooks/VERSION_CHECK_GUIDE.md`
- **Configuration Guide:** `playbooks/CONFIGURATION_GUIDE.md`
- **Upgrade Examples:** `playbooks/host_vars/*-upgrade-example.yml`

---

**Last Updated:** 2026-05-04  
**Maintained by:** IBM Storage Protect Ansible Team