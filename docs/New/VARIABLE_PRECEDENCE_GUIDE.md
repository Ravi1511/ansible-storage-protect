# Ansible Variable Precedence Guide

This guide explains which variables take priority when the same variable is defined in multiple places.

---

## Quick Answer

### **host_vars ALWAYS wins over group_vars**

In your example:

```yaml
# group_vars/ba_clients.yml
ba_client_version: "8.1.27.0"
ba_client_package_path: "/tmp/8.1.27.0-TIV-TSMBAC-LinuxX86.tar"

# host_vars/ba-client-01.yml
ba_client_version: "8.2.1.0"
ba_client_package_path: "/tmp/8.2.1.0-TIV-TSMBAC-LinuxX86.tar"
```

**Result for ba-client-01:**
- ✅ Uses: `ba_client_version: "8.2.1.0"` (from host_vars)
- ✅ Uses: `ba_client_package_path: "/tmp/8.2.1.0-TIV-TSMBAC-LinuxX86.tar"` (from host_vars)

**host_vars has HIGHEST priority and overrides group_vars completely.**

---

## Ansible Variable Precedence (Simplified)

From **LOWEST** to **HIGHEST** priority:

```
1. Role defaults (roles/*/defaults/main.yml)          ← Lowest priority
2. Inventory file variables
3. Inventory group_vars/all.yml
4. Inventory group_vars/<group_name>.yml
5. Inventory host_vars/<hostname>.yml                 ← HIGHEST priority
6. Extra vars (-e on command line)                    ← Can override everything
```

---

## Detailed Precedence for This Project

### Priority Order (Lowest to Highest):

| Priority | Location | Example | When Used |
|----------|----------|---------|-----------|
| 1 (Lowest) | Role defaults | `roles/ba_client_install/defaults/main.yml` | Default values if nothing else set |
| 2 | Playbook defaults | Hardcoded in playbook | Rarely used in this project |
| 3 | Global group vars | `playbooks/group_vars/all.yml` | Defaults for ALL hosts |
| 4 | Group vars | `playbooks/group_vars/ba_clients.yml` | Defaults for ba_clients group |
| 5 | Host vars | `playbooks/host_vars/ba-client-01.yml` | **Specific to ba-client-01** |
| 6 (Highest) | Extra vars | `-e "ba_client_version=8.2.2.0"` | Command-line override |

---

## Real-World Examples

### Example 1: Your Scenario

**Configuration:**

```yaml
# playbooks/group_vars/ba_clients.yml
ba_client_version: "8.1.27.0"
ba_client_package_path: "/tmp/8.1.27.0-TIV-TSMBAC-LinuxX86.tar"
ba_client_start_daemon: false

# playbooks/host_vars/ba-client-01.yml
ba_client_version: "8.2.1.0"
ba_client_package_path: "/tmp/8.2.1.0-TIV-TSMBAC-LinuxX86.tar"
# Note: ba_client_start_daemon NOT defined here
```

**Result for ba-client-01:**

```yaml
ba_client_version: "8.2.1.0"                                    # From host_vars (overrides group_vars)
ba_client_package_path: "/tmp/8.2.1.0-TIV-TSMBAC-LinuxX86.tar" # From host_vars (overrides group_vars)
ba_client_start_daemon: false                                   # From group_vars (not overridden)
```

**Key Point:** host_vars overrides group_vars, but only for variables it defines. Other variables still come from group_vars.

---

### Example 2: Multiple Hosts with Different Versions

**Configuration:**

```yaml
# playbooks/group_vars/ba_clients.yml (default for all BA clients)
ba_client_version: "8.1.27.0"
ba_client_package_path: "/tmp/8.1.27.0-TIV-TSMBAC-LinuxX86.tar"
ba_client_start_daemon: false

# playbooks/host_vars/ba-client-01.yml (specific override)
ba_client_version: "8.2.1.0"
ba_client_package_path: "/tmp/8.2.1.0-TIV-TSMBAC-LinuxX86.tar"

# playbooks/host_vars/ba-client-02.yml (specific override)
ba_client_version: "8.2.0.0"
ba_client_package_path: "/tmp/8.2.0.0-TIV-TSMBAC-LinuxX86.tar"
ba_client_start_daemon: true  # Also override daemon setting

# ba-client-03 has NO host_vars file
```

**Results:**

| Host | Version Used | Package Path Used | Start Daemon | Source |
|------|--------------|-------------------|--------------|--------|
| ba-client-01 | 8.2.1.0 | /tmp/8.2.1.0-TIV-TSMBAC-LinuxX86.tar | false | host_vars + group_vars |
| ba-client-02 | 8.2.0.0 | /tmp/8.2.0.0-TIV-TSMBAC-LinuxX86.tar | true | host_vars |
| ba-client-03 | 8.1.27.0 | /tmp/8.1.27.0-TIV-TSMBAC-LinuxX86.tar | false | group_vars (no host_vars) |

---

### Example 3: Command-Line Override (Highest Priority)

**Configuration:**

```yaml
# playbooks/group_vars/ba_clients.yml
ba_client_version: "8.1.27.0"

# playbooks/host_vars/ba-client-01.yml
ba_client_version: "8.2.1.0"
```

**Command:**

```bash
ansible-playbook playbooks/petascale_install.yml \
  -i playbooks/inventory/petascale.ini \
  -e "ba_client_version=8.2.2.0"
```

**Result for ba-client-01:**

```yaml
ba_client_version: "8.2.2.0"  # From -e (overrides EVERYTHING)
```

**Priority:** Command-line `-e` overrides both host_vars and group_vars.

---

## Visual Precedence Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  Command Line: -e "ba_client_version=8.2.2.0"               │ ← HIGHEST
│  (Overrides everything)                                      │
└─────────────────────────────────────────────────────────────┘
                            ↓ overrides
┌─────────────────────────────────────────────────────────────┐
│  host_vars/ba-client-01.yml                                  │
│  ba_client_version: "8.2.1.0"                               │
└─────────────────────────────────────────────────────────────┘
                            ↓ overrides
┌─────────────────────────────────────────────────────────────┐
│  group_vars/ba_clients.yml                                   │
│  ba_client_version: "8.1.27.0"                              │
└─────────────────────────────────────────────────────────────┘
                            ↓ overrides
┌─────────────────────────────────────────────────────────────┐
│  group_vars/all.yml                                          │
│  ba_client_version: "8.1.24.0"                              │
└─────────────────────────────────────────────────────────────┘
                            ↓ overrides
┌─────────────────────────────────────────────────────────────┐
│  roles/ba_client_install/defaults/main.yml                   │
│  ba_client_version: "8.1.0.0"                               │ ← LOWEST
└─────────────────────────────────────────────────────────────┘
```

---

## How to Check Which Variables Are Being Used

### Method 1: Use ansible-inventory

```bash
# Check all variables for a specific host
ansible-inventory -i playbooks/inventory/petascale.ini \
  --host ba-client-01 \
  --yaml

# Output shows final merged variables (after precedence applied)
```

### Method 2: Use debug in Playbook

Add this to your playbook:

```yaml
- name: Debug variables
  hosts: ba_clients
  tasks:
    - name: Show ba_client_version
      ansible.builtin.debug:
        msg: "ba_client_version = {{ ba_client_version }}"
    
    - name: Show ba_client_package_path
      ansible.builtin.debug:
        msg: "ba_client_package_path = {{ ba_client_package_path }}"
```

### Method 3: Use ansible-playbook with --check and -v

```bash
ansible-playbook playbooks/petascale_install.yml \
  -i playbooks/inventory/petascale.ini \
  --check \
  -v \
  --limit ba-client-01
```

---

## Common Scenarios and Solutions

### Scenario 1: Want Same Version for Most Hosts, Different for One

**Solution:** Use group_vars for default, host_vars for exception

```yaml
# group_vars/ba_clients.yml (default for most)
ba_client_version: "8.1.27.0"

# host_vars/ba-client-special.yml (exception)
ba_client_version: "8.2.1.0"
```

**Result:**
- Most hosts: Use 8.1.27.0 (from group_vars)
- ba-client-special: Uses 8.2.1.0 (from host_vars)

---

### Scenario 2: Want to Test New Version on One Host

**Solution:** Create host_vars file for test host only

```yaml
# group_vars/ba_clients.yml (production version)
ba_client_version: "8.1.27.0"

# host_vars/ba-client-test.yml (test version)
ba_client_version: "8.2.1.0"
```

**Result:**
- Production hosts: Use 8.1.27.0
- Test host: Uses 8.2.1.0

---

### Scenario 3: Emergency Override for All Hosts

**Solution:** Use command-line -e

```bash
# Override version for ALL hosts temporarily
ansible-playbook playbooks/petascale_install.yml \
  -i playbooks/inventory/petascale.ini \
  -e "ba_client_version=8.1.28.0"
```

**Result:** All hosts use 8.1.28.0, regardless of group_vars or host_vars

---

## Best Practices

### 1. Use group_vars for Defaults

```yaml
# playbooks/group_vars/ba_clients.yml
# Default version for all BA clients
ba_client_version: "8.1.27.0"
ba_client_package_path: "/tmp/8.1.27.0-TIV-TSMBAC-LinuxX86.tar"
ba_client_start_daemon: false
```

**Benefit:** Easy to update default for all hosts

---

### 2. Use host_vars for Exceptions

```yaml
# playbooks/host_vars/ba-client-special.yml
# This host needs different version
ba_client_version: "8.2.1.0"
ba_client_package_path: "/tmp/8.2.1.0-TIV-TSMBAC-LinuxX86.tar"
```

**Benefit:** Clear which hosts are different

---

### 3. Document Why host_vars Differs

```yaml
# playbooks/host_vars/ba-client-01.yml
---
# This host uses newer version for testing
# Ticket: JIRA-12345
# Date: 2026-05-04
# Reason: Testing 8.2.1.0 before rolling out to all hosts

ba_client_version: "8.2.1.0"
ba_client_package_path: "/tmp/8.2.1.0-TIV-TSMBAC-LinuxX86.tar"
```

**Benefit:** Team knows why this host is different

---

### 4. Use -e for Temporary Overrides Only

```bash
# Good: Temporary test
ansible-playbook playbooks/petascale_install.yml \
  -i playbooks/inventory/petascale.ini \
  -e "ba_client_version=8.2.0.0" \
  --limit ba-client-test

# Bad: Don't use -e for permanent changes
# Instead, update group_vars or host_vars files
```

**Benefit:** Configuration is in version control, not command history

---

## Troubleshooting

### Issue: Variable Not Taking Effect

**Problem:** Changed group_vars but host still uses old value

**Solution:** Check if host_vars exists and overrides it

```bash
# Check what host is actually using
ansible-inventory -i playbooks/inventory/petascale.ini \
  --host ba-client-01 \
  --yaml | grep ba_client_version

# Check if host_vars file exists
ls -la playbooks/host_vars/ba-client-01.yml
```

---

### Issue: Don't Know Which File Variable Comes From

**Problem:** Variable is set somewhere but don't know where

**Solution:** Check in order of precedence

```bash
# 1. Check host_vars (highest priority)
grep ba_client_version playbooks/host_vars/ba-client-01.yml

# 2. Check group_vars
grep ba_client_version playbooks/group_vars/ba_clients.yml

# 3. Check global vars
grep ba_client_version playbooks/group_vars/all.yml

# 4. Check role defaults (lowest priority)
grep ba_client_version roles/ba_client_install/defaults/main.yml
```

---

### Issue: Want to Remove host_vars Override

**Problem:** Host was using custom version, now want to use group default

**Solution:** Delete or comment out the variable in host_vars

```yaml
# playbooks/host_vars/ba-client-01.yml
---
# Commented out - now using group_vars default
# ba_client_version: "8.2.1.0"
# ba_client_package_path: "/tmp/8.2.1.0-TIV-TSMBAC-LinuxX86.tar"

# Or delete the file entirely if no other custom settings
```

---

## Summary Table

| Variable Location | Priority | Use Case | Example |
|-------------------|----------|----------|---------|
| **host_vars** | **Highest** | Host-specific settings | Test host with new version |
| **group_vars** | Medium | Group defaults | All BA clients use 8.1.27.0 |
| **all.yml** | Low | Global defaults | Common settings for all hosts |
| **role defaults** | Lowest | Fallback values | If nothing else is set |
| **-e (command line)** | **Override All** | Temporary override | Emergency version change |

---

## Key Takeaways

1. ✅ **host_vars ALWAYS wins** over group_vars
2. ✅ **group_vars** provides defaults for all hosts in a group
3. ✅ **host_vars** overrides group_vars for specific hosts
4. ✅ **-e** on command line overrides everything (use sparingly)
5. ✅ **Document** why host_vars differs from group_vars
6. ✅ **Use ansible-inventory** to see final merged variables

---

## Related Documentation

- **Variable Configuration Guide:** `playbooks/VARIABLE_CONFIGURATION_GUIDE.md`
- **Upgrade Behavior Guide:** `playbooks/UPGRADE_BEHAVIOR_GUIDE.md`
- **Host Vars README:** `playbooks/host_vars/README.md`
- **Ansible Documentation:** https://docs.ansible.com/ansible/latest/user_guide/playbooks_variables.html#variable-precedence-where-should-i-put-a-variable

---

**Last Updated:** 2026-05-04  
**Maintained by:** IBM Storage Protect Ansible Team