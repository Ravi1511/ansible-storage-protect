# Petascale Multi-Server HSM Automation Fix Plan

**Document Version:** 1.0  
**Date:** June 22, 2026  
**Author:** Based on manual testing and troubleshooting session  
**Purpose:** Step-by-step plan to fix automation based on manual testing discoveries

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Issues Discovered During Manual Testing](#issues-discovered-during-manual-testing)
3. [Root Cause Analysis](#root-cause-analysis)
4. [Step-by-Step Fix Plan](#step-by-step-fix-plan)
5. [Implementation Checklist](#implementation-checklist)
6. [Testing Strategy](#testing-strategy)
7. [Reference Commands](#reference-commands)

---

## Executive Summary

### What We Discovered

During manual testing of the Petascale multi-server HSM configuration, we discovered several critical issues that need to be fixed in the automation:

1. **DMAPI Not Enabled** - Filesystem was created without DMAPI support
2. **Firewall Blocking Connections** - Port 1500 not open on SP servers
3. **SSL Certificate Issues** - Certificates not imported for multi-server setup
4. **Active Server Binding Not Automated** - Manual steps required after backup
5. **Invalid Commands in Playbook** - Non-existent TSM commands used
6. **Missing Error Handling** - No validation of prerequisites

### Current Status

✅ **Working Manually:**
- Multi-server configuration (PETASCALE-SP01 & PETASCALE-SP03)
- Node registration on both servers
- SSL certificate import
- HSM filesystem management
- Shadow database creation

❌ **Not Working in Automation:**
- DMAPI prerequisite check and enablement
- Firewall port automation
- Multi-server certificate import
- Active server binding setup
- Command validation

---

## Issues Discovered During Manual Testing

### Issue 1: DMAPI Not Enabled on GPFS Filesystem

**Symptom:**
```
ANS9501W dsmmigfs: cannot set event disposition on session
ANS9086E dsmmigfs: A DMAPI error
```

**Root Cause:**
- GPFS filesystem created with `-z no` (DMAPI disabled)
- HSM requires DMAPI for space management operations

**Manual Fix Applied:**
```bash
mmchfs gpfs_main -z yes
mmmount gpfs_main
dsmmigfs add /gpfs_main
```

**Automation Gap:**
- Playbook checks if DMAPI is enabled but doesn't enable it
- No automatic remediation

---

### Issue 2: Firewall Port 1500 Not Open on SP Servers

**Symptom:**
```
ANS1017E (RC2)  Session rejected: TCP/IP connection failure
```

**Root Cause:**
- Firewall blocking port 1500 on SP servers
- Both runtime and permanent rules needed

**Manual Fix Applied:**
```bash
# On each SP server
sudo firewall-cmd --add-port=1500/tcp              # Runtime
sudo firewall-cmd --permanent --add-port=1500/tcp  # Permanent
sudo firewall-cmd --query-port=1500/tcp            # Verify
```

**Automation Gap:**
- No firewall configuration in playbook
- Assumes ports are already open

---

### Issue 3: SSL Certificate Not Imported for Multi-Server

**Symptom:**
```
ANS1592E An error occurred initializing the Trusted Services Library
```

**Root Cause:**
- Certificates not imported for PETASCALE-SP01 and PETASCALE-SP03
- BA client and HSM client share same certificate store
- `dsmcert` only exists in BA client, not HSM client

**Manual Fix Applied:**
```bash
# Import certificates using BA client's dsmcert
/opt/tivoli/tsm/client/ba/bin/dsmcert -add -server PETASCALE-SP01
/opt/tivoli/tsm/client/ba/bin/dsmcert -add -server PETASCALE-SP03
```

**Automation Gap:**
- Certificate import only tests default server
- Doesn't loop through all servers in multi-server config
- Uses wrong path (tries HSM client path instead of BA client path)

---

### Issue 4: Active Server Binding Not Automated

**Symptom:**
```bash
mmlsattr -d -L /gpfs_main/fileset_2/test.txt | grep IBMServ
# No output - attribute not set
```

**Root Cause:**
- `mmbackup` creates shadow DB but doesn't set `dmapi.IBMServ` attribute
- Manual `mmputattr` or `setfattr` required
- Command not in PATH (`/usr/lpp/mmfs/bin/mmputattr`)

**Manual Fix Applied:**
```bash
/usr/lpp/mmfs/bin/mmputattr -k dmapi.IBMServ -v PETASCALE-SP01 /gpfs_main/fileset_2/test.txt
# OR
setfattr -n user.dmapi.IBMServ -v PETASCALE-SP01 /gpfs_main/fileset_2/test.txt
```

**Automation Gap:**
- No active server binding automation
- Relies on `mmbackup` which doesn't set the attribute
- No GPFS policy automation

---

### Issue 5: Invalid TSM Commands in Playbook

**Symptom:**
```
ANS8001I Return code 3 (Command not found)
```

**Root Cause:**
- Playbook uses non-existent commands:
  - `querymultiserver` - doesn't exist in TSM 8.2.0.0
  - `dsmmigfs add -server=` - invalid parameter

**Manual Fix Applied:**
- Removed `querymultiserver` references
- Changed to `dsmmigfs add /gpfs_main` (no -server parameter)

**Automation Gap:**
- Commands not validated against TSM version
- No error handling for invalid commands

---

### Issue 6: dsm.sys Configuration Mismatch

**Symptom:**
```
ANS1036S The option 'PETASCALE-SP02' or the value supplied for it is not valid
```

**Root Cause:**
- BA client dsm.sys had old configuration with PETASCALE-SP02
- HSM client dsm.sys was correct
- Files not synchronized

**Manual Fix Applied:**
```bash
cp /opt/tivoli/tsm/client/hsm/bin/dsm.sys /opt/tivoli/tsm/client/ba/bin/dsm.sys
```

**Automation Gap:**
- BA and HSM dsm.sys created separately
- No validation that both files match
- No cleanup of old configurations

---

## Root Cause Analysis

### Why These Issues Occurred

1. **Incomplete Prerequisites**
   - DMAPI enablement assumed, not verified
   - Firewall configuration not included
   - GPFS commands not in PATH

2. **Multi-Server Complexity**
   - Certificate import logic only handles single server
   - Active server binding not understood
   - Shadow DB creation confused with attribute setting

3. **Command Validation**
   - TSM commands not validated against version
   - Invalid parameters not caught
   - No error handling for missing commands

4. **Configuration Synchronization**
   - BA and HSM clients configured independently
   - No validation of consistency
   - Old configurations not cleaned up

---

## Step-by-Step Fix Plan

### Phase 1: Fix DMAPI Prerequisites (Priority: CRITICAL)

**File:** `ansible-ibm-storage-protect-2/playbooks/petascale_configure.yml`  
**Lines:** 767-825 (DMAPI check section)

**Current Code:**
```yaml
- name: Check if DMAPI is enabled on GPFS filesystem
  ansible.builtin.shell: |
    mmlsfs {{ gpfs_filesystem }} -z
  register: dmapi_check
  failed_when: false
  changed_when: false

- name: Display DMAPI status
  ansible.builtin.debug:
    msg: |
      CRITICAL: DMAPI is DISABLED on {{ gpfs_filesystem }}
      Active server binding will NOT work without DMAPI!
  when: "'--dmapi no' in dmapi_check.stdout or '-z no' in dmapi_check.stdout"
```

**Required Changes:**
```yaml
- name: Check if DMAPI is enabled on GPFS filesystem
  ansible.builtin.shell: |
    mmlsfs {{ item.domain.split('/')[1] }} -z 2>&1 | grep -i dmapi
  register: dmapi_check
  failed_when: false
  changed_when: false
  loop: "{{ sp_servers }}"
  when: sp_servers is defined

- name: Enable DMAPI if disabled
  ansible.builtin.shell: |
    mmunmount {{ item.domain.split('/')[1] }}
    mmchfs {{ item.domain.split('/')[1] }} -z yes
    mmmount {{ item.domain.split('/')[1] }}
  loop: "{{ sp_servers }}"
  when:
    - sp_servers is defined
    - dmapi_check.results[loop_index].stdout is defined
    - "'--dmapi no' in dmapi_check.results[loop_index].stdout or '-z no' in dmapi_check.results[loop_index].stdout"
  register: dmapi_enable
  
- name: Verify DMAPI is now enabled
  ansible.builtin.shell: |
    mmlsfs {{ item.domain.split('/')[1] }} -z
  register: dmapi_verify
  loop: "{{ sp_servers }}"
  when: sp_servers is defined
  failed_when: "'--dmapi yes' not in dmapi_verify.stdout and '-z yes' not in dmapi_verify.stdout"
```

**Testing:**
- Verify DMAPI check works on disabled filesystem
- Verify automatic enablement works
- Verify verification catches failures

---

### Phase 2: Fix Firewall Port Automation (Priority: CRITICAL)

**File:** `ansible-ibm-storage-protect-2/playbooks/petascale_configure.yml`  
**Location:** Add new section after SP server configuration

**New Code to Add:**
```yaml
# ============================================================================
# Configure Firewall on SP Servers
# ============================================================================

- name: Configure firewall on SP servers
  hosts: sp_servers
  gather_facts: yes
  become: yes
  tasks:
    - name: Check if firewalld is running
      ansible.builtin.systemd:
        name: firewalld
      register: firewalld_status
      failed_when: false

    - name: Open TSM port 1500 in firewall (runtime)
      ansible.posix.firewalld:
        port: 1500/tcp
        permanent: no
        state: enabled
        immediate: yes
      when: firewalld_status.status.ActiveState == "active"
      register: firewall_runtime

    - name: Open TSM port 1500 in firewall (permanent)
      ansible.posix.firewalld:
        port: 1500/tcp
        permanent: yes
        state: enabled
      when: firewalld_status.status.ActiveState == "active"
      register: firewall_permanent

    - name: Reload firewall
      ansible.builtin.command: firewall-cmd --reload
      when:
        - firewalld_status.status.ActiveState == "active"
        - firewall_permanent is changed

    - name: Verify port 1500 is open
      ansible.builtin.command: firewall-cmd --query-port=1500/tcp
      register: port_check
      failed_when: "'yes' not in port_check.stdout"
      when: firewalld_status.status.ActiveState == "active"

    - name: Display firewall status
      ansible.builtin.debug:
        msg: |
          Firewall Configuration:
          - Port 1500/tcp: {{ 'OPEN' if port_check.stdout == 'yes' else 'CLOSED' }}
          - Runtime rule: {{ 'Added' if firewall_runtime is changed else 'Already exists' }}
          - Permanent rule: {{ 'Added' if firewall_permanent is changed else 'Already exists' }}
```

**Testing:**
- Test on server with firewall enabled
- Test on server with firewall disabled
- Verify port opens in both runtime and permanent
- Verify idempotency (running twice doesn't fail)

---

### Phase 3: Fix Multi-Server Certificate Import (Priority: HIGH)

**File:** `ansible-ibm-storage-protect-2/roles/ba_client_install/tasks/ba_client_cert_fix.yml`

**Current Code (lines ~50-80):**
```yaml
- name: Test connection to default server
  ansible.builtin.shell: |
    dsmc query session -servername={{ default_server }}
  register: test_connection
  failed_when: false
```

**Required Changes:**
```yaml
- name: Import SSL certificates for all servers (multi-server support)
  ansible.builtin.shell: |
    echo "yes" | /opt/tivoli/tsm/client/ba/bin/dsmcert -add -server {{ item.name }}
  loop: "{{ sp_servers }}"
  when:
    - sp_servers is defined
    - item.name is defined
  register: cert_import_multi
  failed_when: false
  changed_when: "'Certificate imported' in cert_import_multi.stdout"

- name: Verify certificates imported for all servers
  ansible.builtin.shell: |
    /opt/tivoli/tsm/client/ba/bin/dsmcert -list
  register: cert_list
  failed_when: false

- name: Display certificate status
  ansible.builtin.debug:
    msg: |
      SSL Certificates Status:
      {% for server in sp_servers %}
      - {{ server.name }}: {{ 'Imported' if server.name in cert_list.stdout else 'MISSING' }}
      {% endfor %}

- name: Test connection to all servers
  ansible.builtin.shell: |
    dsmc query session -servername={{ item.name }}
  loop: "{{ sp_servers }}"
  when: sp_servers is defined
  register: test_connections
  failed_when: false

- name: Display connection test results
  ansible.builtin.debug:
    msg: |
      Connection Test Results:
      {% for result in test_connections.results %}
      - {{ result.item.name }}: {{ 'SUCCESS' if result.rc == 0 else 'FAILED' }}
      {% endfor %}
```

**Testing:**
- Test with single server configuration
- Test with multi-server configuration
- Verify all certificates imported
- Verify connections work to all servers

---

### Phase 4: Fix Active Server Binding Automation (Priority: HIGH)

**File:** `ansible-ibm-storage-protect-2/playbooks/petascale_configure.yml`  
**Location:** Add new section after HSM filesystem setup

**New Code to Add:**
```yaml
# ============================================================================
# Configure Active Server Binding (Petascale Multi-Server)
# ============================================================================

- name: Configure active server binding for multi-server setup
  when:
    - sp_servers is defined
    - sp_servers | length > 1
  block:
    - name: Check if mmputattr command exists
      ansible.builtin.stat:
        path: /usr/lpp/mmfs/bin/mmputattr
      register: mmputattr_check

    - name: Check if setfattr command exists
      ansible.builtin.command: which setfattr
      register: setfattr_check
      failed_when: false
      changed_when: false

    - name: Install attr package if setfattr not found
      ansible.builtin.package:
        name: attr
        state: present
      when:
        - not mmputattr_check.stat.exists
        - setfattr_check.rc != 0

    - name: Create GPFS policy file for automatic active server binding
      ansible.builtin.template:
        src: hsm_active_binding_policy.j2
        dest: /tmp/hsm_active_binding_policy.txt
        mode: '0644'
      register: policy_file

    - name: Apply GPFS policy to set active server binding
      ansible.builtin.shell: |
        /usr/lpp/mmfs/bin/mmapplypolicy {{ gpfs_filesystem }} \
          -P /tmp/hsm_active_binding_policy.txt \
          -I defer
      when: policy_file is changed
      register: policy_apply
      failed_when: false

    - name: Set active server binding using mmputattr (if available)
      ansible.builtin.shell: |
        find {{ item.domain }} -type f -exec /usr/lpp/mmfs/bin/mmputattr -k dmapi.IBMServ -v {{ item.name }} {} \;
      loop: "{{ sp_servers }}"
      when:
        - mmputattr_check.stat.exists
        - policy_apply.rc != 0
      register: mmputattr_result
      failed_when: false

    - name: Set active server binding using setfattr (fallback)
      ansible.builtin.shell: |
        find {{ item.domain }} -type f -exec setfattr -n user.dmapi.IBMServ -v {{ item.name }} {} \;
      loop: "{{ sp_servers }}"
      when:
        - not mmputattr_check.stat.exists
        - setfattr_check.rc == 0
        - policy_apply.rc != 0
      register: setfattr_result
      failed_when: false

    - name: Verify active server binding
      ansible.builtin.shell: |
        /usr/lpp/mmfs/bin/mmlsattr -d -L {{ item.domain }}/test_binding_{{ item.name }}.txt 2>/dev/null | grep IBMServ || \
        getfattr -n user.dmapi.IBMServ {{ item.domain }}/test_binding_{{ item.name }}.txt 2>/dev/null
      loop: "{{ sp_servers }}"
      register: binding_verify
      failed_when: false
      changed_when: false

    - name: Display active server binding status
      ansible.builtin.debug:
        msg: |
          Active Server Binding Status:
          {% for result in binding_verify.results %}
          - {{ result.item.domain }} → {{ result.item.name }}: {{ 'CONFIGURED' if result.item.name in result.stdout else 'NOT SET' }}
          {% endfor %}

    - name: Create disaster recovery documentation
      ansible.builtin.template:
        src: active_binding_dr_doc.j2
        dest: "{{ gpfs_filesystem }}/config/active_binding_config_{{ inventory_hostname }}.txt"
        mode: '0644'
```

**New Template File:** `ansible-ibm-storage-protect-2/roles/hsm_client_install/templates/hsm_active_binding_policy.j2`
```jinja2
/* GPFS Policy for Automatic Active Server Binding */
/* Generated by Ansible for {{ inventory_hostname }} */
/* Date: {{ ansible_date_time.iso8601 }} */

{% for server in sp_servers %}
RULE 'BindTo{{ server.name }}'
  LIST '{{ server.name }}_files'
  WHERE PATH_NAME LIKE '{{ server.domain }}/%'
  DO SET_DMATTR('dmapi.IBMServ', '{{ server.name }}')
{% endfor %}
```

**Testing:**
- Test GPFS policy creation and application
- Test mmputattr fallback
- Test setfattr fallback
- Verify binding is set correctly
- Test with multiple filesets

---

### Phase 5: Remove Invalid Commands (Priority: MEDIUM)

**File:** `ansible-ibm-storage-protect-2/playbooks/petascale_configure.yml`

**Changes Required:**

1. **Remove querymultiserver command** (lines ~850-870):
```yaml
# DELETE THIS BLOCK:
- name: Query multi-server configuration
  ansible.builtin.shell: |
    dsmadmc -se={{ default_server }} "querymultiserver"
  register: multiserver_query
```

2. **Fix dsmmigfs add command** (lines ~826-868):
```yaml
# CHANGE FROM:
- name: Add filesystem to HSM management
  ansible.builtin.shell: |
    dsmmigfs add {{ gpfs_filesystem }} -server={{ item.name }}

# CHANGE TO:
- name: Add filesystem to HSM management (First Time Setup)
  ansible.builtin.shell: |
    dsmmigfs add {{ gpfs_filesystem }}
  register: dsmmigfs_add
  failed_when:
    - dsmmigfs_add.rc != 0
    - "'already managed' not in dsmmigfs_add.stderr"
  changed_when: "'successfully added' in dsmmigfs_add.stdout"
```

3. **Add command validation**:
```yaml
- name: Validate TSM commands exist
  ansible.builtin.shell: |
    which {{ item }}
  loop:
    - dsmmigfs
    - dsmmigrate
    - dsmrecall
    - dsmc
  register: command_check
  failed_when: command_check.rc != 0
  changed_when: false
```

**Testing:**
- Verify invalid commands removed
- Verify valid commands work
- Test error handling

---

### Phase 6: Add Configuration Validation (Priority: MEDIUM)

**File:** `ansible-ibm-storage-protect-2/playbooks/petascale_configure.yml`  
**Location:** Add new section at the end

**New Code to Add:**
```yaml
# ============================================================================
# Final Validation and Health Check
# ============================================================================

- name: Perform final validation of HSM multi-server setup
  hosts: hsm_clients
  gather_facts: no
  become: yes
  tasks:
    - name: Validate dsm.sys configuration
      ansible.builtin.shell: |
        grep -c "SERVERNAME" /opt/tivoli/tsm/client/hsm/bin/dsm.sys
      register: dsm_sys_servers
      failed_when: dsm_sys_servers.stdout | int != sp_servers | length
      changed_when: false

    - name: Validate dsm.opt configuration
      ansible.builtin.shell: |
        grep "HSMMULTISERVER" /opt/tivoli/tsm/client/hsm/bin/dsm.opt
      register: dsm_opt_multi
      failed_when: "'YES' not in dsm_opt_multi.stdout"
      changed_when: false

    - name: Validate HSM filesystem management
      ansible.builtin.shell: |
        dsmmigfs query {{ gpfs_filesystem }}
      register: hsm_query
      failed_when: hsm_query.rc != 0
      changed_when: false

    - name: Validate DMAPI enabled
      ansible.builtin.shell: |
        mmlsfs {{ gpfs_filesystem.split('/')[1] }} -z
      register: dmapi_final
      failed_when: "'yes' not in dmapi_final.stdout"
      changed_when: false

    - name: Validate certificates imported
      ansible.builtin.shell: |
        /opt/tivoli/tsm/client/ba/bin/dsmcert -list
      register: cert_final
      failed_when: false
      changed_when: false

    - name: Validate node registration
      ansible.builtin.shell: |
        dsmc query session -servername={{ item.name }}
      loop: "{{ sp_servers }}"
      register: session_final
      failed_when: false
      changed_when: false

    - name: Generate validation report
      ansible.builtin.template:
        src: validation_report.j2
        dest: "{{ gpfs_filesystem }}/config/validation_report_{{ inventory_hostname }}_{{ ansible_date_time.epoch }}.txt"
        mode: '0644'

    - name: Display validation summary
      ansible.builtin.debug:
        msg: |
          ========================================
          HSM Multi-Server Validation Summary
          ========================================
          Host: {{ inventory_hostname }}
          
          Configuration:
          - Servers configured: {{ dsm_sys_servers.stdout }}
          - Multi-server enabled: {{ 'YES' if 'YES' in dsm_opt_multi.stdout else 'NO' }}
          - HSM management: {{ 'Active' if hsm_query.rc == 0 else 'FAILED' }}
          - DMAPI enabled: {{ 'YES' if 'yes' in dmapi_final.stdout else 'NO' }}
          
          Connectivity:
          {% for result in session_final.results %}
          - {{ result.item.name }}: {{ 'Connected' if result.rc == 0 else 'FAILED' }}
          {% endfor %}
          
          Status: {{ 'READY' if hsm_query.rc == 0 and 'yes' in dmapi_final.stdout else 'NEEDS ATTENTION' }}
          ========================================
```

**New Template File:** `ansible-ibm-storage-protect-2/roles/hsm_client_install/templates/validation_report.j2`
```jinja2
HSM Multi-Server Configuration Validation Report
================================================
Generated: {{ ansible_date_time.iso8601 }}
Host: {{ inventory_hostname }}
Ansible User: {{ ansible_user }}

Configuration Summary
---------------------
GPFS Filesystem: {{ gpfs_filesystem }}
Default Server: {{ default_server }}
Number of Servers: {{ sp_servers | length }}

Server Configuration
--------------------
{% for server in sp_servers %}
Server {{ loop.index }}: {{ server.name }}
  Address: {{ server.address }}:{{ server.port }}
  Node Name: {{ server.node_name }}
  Domain: {{ server.domain }}
{% endfor %}

Validation Results
------------------
✓ dsm.sys: {{ dsm_sys_servers.stdout }} servers configured
✓ dsm.opt: Multi-server {{ 'ENABLED' if 'YES' in dsm_opt_multi.stdout else 'DISABLED' }}
✓ HSM Management: {{ 'Active' if hsm_query.rc == 0 else 'FAILED' }}
✓ DMAPI: {{ 'Enabled' if 'yes' in dmapi_final.stdout else 'DISABLED' }}

Connectivity Status
-------------------
{% for result in session_final.results %}
{{ result.item.name }}: {{ 'Connected' if result.rc == 0 else 'FAILED' }}
{% endfor %}

Certificate Status
------------------
{{ cert_final.stdout }}

Overall Status
--------------
{{ 'READY FOR PRODUCTION' if hsm_query.rc == 0 and 'yes' in dmapi_final.stdout else 'CONFIGURATION INCOMPLETE' }}

Next Steps
----------
{% if hsm_query.rc != 0 or 'yes' not in dmapi_final.stdout %}
1. Review failed validation checks above
2. Fix configuration issues
3. Re-run validation
{% else %}
1. Test migration: dsmmigrate <file>
2. Test recall: dsmrecall <file>
3. Schedule regular backups
4. Monitor TSM server storage
{% endif %}
```

**Testing:**
- Run validation on working configuration
- Run validation on broken configuration
- Verify report generation
- Verify all checks work

---

## Implementation Checklist

### Pre-Implementation

- [ ] Backup current playbook: `cp petascale_configure.yml petascale_configure.yml.backup`
- [ ] Review all manual testing notes
- [ ] Identify test environment for validation
- [ ] Prepare rollback plan

### Phase 1: DMAPI Prerequisites

- [ ] Update DMAPI check logic
- [ ] Add DMAPI enablement automation
- [ ] Add verification step
- [ ] Test on filesystem with DMAPI disabled
- [ ] Test on filesystem with DMAPI enabled
- [ ] Verify idempotency

### Phase 2: Firewall Automation

- [ ] Add firewall configuration section
- [ ] Test on server with firewalld active
- [ ] Test on server with firewalld inactive
- [ ] Verify port opens correctly
- [ ] Verify permanent rules persist after reboot
- [ ] Test idempotency

### Phase 3: Multi-Server Certificates

- [ ] Update certificate import logic
- [ ] Add loop for all servers
- [ ] Add verification for each server
- [ ] Test with single server
- [ ] Test with multiple servers
- [ ] Verify all certificates imported

### Phase 4: Active Server Binding

- [ ] Create GPFS policy template
- [ ] Add policy application logic
- [ ] Add mmputattr fallback
- [ ] Add setfattr fallback
- [ ] Add verification
- [ ] Test all three methods
- [ ] Verify binding persists

### Phase 5: Remove Invalid Commands

- [ ] Remove querymultiserver references
- [ ] Fix dsmmigfs add command
- [ ] Add command validation
- [ ] Test all TSM commands
- [ ] Verify error handling

### Phase 6: Add Validation

- [ ] Create validation section
- [ ] Create validation report template
- [ ] Test validation on working config
- [ ] Test validation on broken config
- [ ] Verify report generation

### Post-Implementation

- [ ] Run complete playbook end-to-end
- [ ] Verify all manual steps now automated
- [ ] Generate validation report
- [ ] Document any remaining manual steps
- [ ] Update user documentation

---

## Testing Strategy

### Unit Testing (Per Phase)

Each phase should be tested independently:

1. **Create test inventory** with single HSM client
2. **Run only the modified section** using tags
3. **Verify expected behavior**
4. **Test error conditions**
5. **Verify idempotency** (run twice, second run should show no changes)

### Integration Testing

After all phases complete:

1. **Fresh installation test**
   - Start with clean systems
   - Run complete playbook
   - Verify all components work

2. **Upgrade test**
   - Start with existing configuration
   - Run playbook
   - Verify no breaking changes

3. **Multi-server test**
   - Configure 2+ SP servers
   - Verify active server binding
   - Test migration to each server

4. **Failure recovery test**
   - Simulate failures (firewall closed, DMAPI disabled, etc.)
   - Verify playbook detects and fixes issues
   - Verify error messages are clear

### Validation Testing

1. **Run validation section**
2. **Review validation report**
3. **Verify all checks pass**
4. **Test manual operations**:
   - `dsmmigfs query /gpfs_main`
   - `dsmmigrate <file>`
   - `dsmrecall <file>`
   - `mmlsattr -d -L <file> | grep IBMServ`

---

## Reference Commands

### DMAPI Management

```bash
# Check DMAPI status
mmlsfs gpfs_main -z

# Enable DMAPI
mmunmount gpfs_main
mmchfs gpfs_main -z yes
mmmount gpfs_main

# Verify
mmlsfs gpfs_main -z | grep dmapi
```

### Firewall Management

```bash
# Check firewall status
sudo firewall-cmd --state
sudo firewall-cmd --list-ports

# Open port (runtime + permanent)
sudo firewall-cmd --add-port=1500/tcp
sudo firewall-cmd --permanent --add-port=1500/tcp
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --query-port=1500/tcp
```

### Certificate Management

```bash
# Import certificate
/opt/tivoli/tsm/client/ba/bin/dsmcert -add -server PETASCALE-SP01

# List certificates
/opt/tivoli/tsm/client/ba/bin/dsmcert -list

# Test connection
dsmc query session -servername=PETASCALE-SP01
```

### Active Server Binding

```bash
# Method 1: GPFS Policy
cat > /tmp/policy.txt << 'EOF'
RULE 'BindToSP01'
  WHERE PATH_NAME LIKE '/gpfs_main/fileset_2/%'
  DO SET_DMATTR('dmapi.IBMServ', 'PETASCALE-SP01')
EOF
mmapplypolicy /gpfs_main -P /tmp/policy.txt -I defer

# Method 2: mmputattr
/usr/lpp/mmfs/bin/mmputattr -k dmapi.IBMServ -v PETASCALE-SP01 /gpfs_main/fileset_2/test.txt

# Method 3: setfattr
setfattr -n user.dmapi.IBMServ -v PETASCALE-SP01 /gpfs_main/fileset_2/test.txt

# Verify
/usr/lpp/mmfs/bin/mmlsattr -d -L /gpfs_main/fileset_2/test.txt | grep IBMServ
getfattr -n user.dmapi.IBMServ /gpfs_main/fileset_2/test.txt
```

### HSM Operations

```bash
# Add filesystem to HSM
dsmmigfs add /gpfs_main

# Query HSM status
dsmmigfs query /gpfs_main

# Migrate file
dsmmigrate /gpfs_main/fileset_2/test.txt

# Recall file
dsmrecall /gpfs_main/fileset_2/test.txt

# Check migration status
ls -l /gpfs_main/fileset_2/test.txt
```

### Validation Commands

```bash
# Check configuration files
cat /opt/tivoli/tsm/client/hsm/bin/dsm.sys
cat /opt/tivoli/tsm/client/hsm/bin/dsm.opt

# Test connections
dsmc query session -servername=PETASCALE-SP01
dsmc query session -servername=PETASCALE-SP03

# Check node registration
dsmadmc -se=PETASCALE-SP01 "query node hsm-client-03-sp01"
dsmadmc -se=PETASCALE-SP03 "query node hsm-client-03-sp03"
```

---

## Summary

This document provides a comprehensive plan to fix all issues discovered during manual testing. The fixes are organized into 6 phases, each with clear objectives, code changes, and testing requirements.

**Key Improvements:**
1. Automatic DMAPI enablement
2. Firewall port automation
3. Multi-server certificate import
4. Active server binding automation
5. Invalid command removal
6. Comprehensive validation

**Expected Outcome:**
After implementing all phases, the playbook will fully automate the Petascale multi-server HSM configuration with no manual intervention required.

**Next Steps:**
1. Review this plan with the team
2. Implement phases sequentially
3. Test each phase thoroughly
4. Document any additional findings
5. Update user documentation

---

**Document End**