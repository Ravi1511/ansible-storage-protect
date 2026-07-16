# Petascale Multi-Server Implementation Plan

**Document Version:** 1.0  
**Date:** 2026-06-22  
**Status:** Ready for Review  
**Author:** Bob (AI Assistant)

---

## Executive Summary

This document provides a detailed implementation plan to complete the Petascale multi-server configuration for IBM Storage Protect. Based on analysis of IBM's official Petascale Data Protection documentation and your current implementation, this plan addresses critical gaps and provides step-by-step instructions for production deployment.

**Key Findings:**
- ✅ Your GPFS fileset structure is **PERFECT** and production-ready
- ✅ Your SP Server configuration requires **NO CHANGES**
- 🔴 HSM clients need **CRITICAL fixes** (Active Server Binding)
- 🟡 BA clients need **RECOMMENDED improvements** (fileset-level DOMAIN)

---

## Table of Contents

1. [Current Status Assessment](#current-status-assessment)
2. [Priority 1: HSM Client Critical Fixes](#priority-1-hsm-client-critical-fixes)
3. [Priority 2: BA Client Improvements](#priority-2-ba-client-improvements)
4. [Priority 3: Operational Workflows](#priority-3-operational-workflows)
5. [Implementation Timeline](#implementation-timeline)
6. [Testing & Validation](#testing--validation)
7. [Disaster Recovery Documentation](#disaster-recovery-documentation)

---

## Current Status Assessment

### ✅ What's Working Correctly

#### 1. GPFS Fileset Configuration
```bash
[root@p9d-vm4 bin]# mmlsfileset /dev/gpfs_main 
Filesets in file system 'gpfs_main':
Name                     Status    Path                                    
root                     Linked    /gpfs_main                              
testfs                   Linked    /gpfs_main/testfs                       
fileset_1                Linked    /gpfs_main/fileset_1                    
fileset_2                Linked    /gpfs_main/fileset_2                    
fileset_3                Linked    /gpfs_main/fileset_3
```

**Status:** ✅ **PERFECT** - Matches IBM test environment exactly

#### 2. Multi-Server Configuration Structure
**File:** `playbooks/host_vars/hsm-client-03.yml`

```yaml
sp_servers:
  - name: "PETASCALE-SP01"
    address: "9.11.53.28"
    port: "1500"
    node_name: "hsm-client-03-sp01"
    domain: "/gpfs_main/fileset_2"
  - name: "PETASCALE-SP03"
    address: "9.11.53.254"
    port: "1500"
    node_name: "hsm-client-03-sp03"
    domain: "/gpfs_main/fileset_3"

default_server: "PETASCALE-SP01"
```

**Status:** ✅ **CORRECT** - Proper structure with per-server filesets

#### 3. SP Server Configuration
**Status:** ✅ **NO CHANGES NEEDED** - Current configuration is production-ready

---

### 🚨 Critical Gaps Identified

#### Gap 1: Active Server Binding NOT Enabled 🔴 CRITICAL
**Severity:** BLOCKER  
**Impact:** Multi-server setup won't work correctly

**Missing HSM Options in dsm.opt:**
```
HSMMULTISERVER            YES    # ← MISSING!
HSMEXTOBJIDATTR           YES    # ← MISSING!
HSMENABLEIMMEDIATEMIGRATE YES    # ← MISSING!
HSMDISABLEAUTOMIGDAEMONS  YES    # ← MISSING!
```

**Why Critical:**
- Without these options, files can be sent to ANY server
- No `dmapi.IBMServ` attribute will be created
- Cannot enforce fileset-to-server binding
- Data integrity issues in multi-server environment

---

#### Gap 2: HSM Multiple-Server Setup Commands NOT Run 🔴 CRITICAL
**Severity:** BLOCKER  
**Impact:** Active server binding infrastructure not initialized

**Missing Commands:**
```bash
# These MUST be run ONCE per filesystem:
dsmmigfs Add -Server=PETASCALE-SP01 /gpfs_main
dsmmigfs ADDMultiserver -Server=PETASCALE-SP01 /gpfs_main
dsmmigfs ADDMultiserver -Server=PETASCALE-SP03 /gpfs_main

# Verify:
dsmmigfs QUERYMultiserver /gpfs_main
```

---

#### Gap 3: Fileset-to-Server Mapping NOT Documented 🟡 HIGH
**Severity:** HIGH (for disaster recovery)  
**Impact:** Disaster recovery will be difficult

**IBM Requirement:**
> "Before you start operations to back up or migrate files to different servers, you must document the correlation between filesets and server names. This step is important to allow the reconstruction of the environment after a system failure or a disaster."

---

#### Gap 4: BA Client DOMAIN Uses Filesystem Root 🟡 MEDIUM
**Severity:** MEDIUM  
**Impact:** Less precise backup control

**Current:**
```yaml
DOMAIN {{ gpfs_filesystem }}  # Uses /gpfs_main
```

**Should Be:**
```yaml
DOMAIN {{ server.domain }}  # Uses /gpfs_main/fileset_X
```

---

## Priority 1: HSM Client Critical Fixes

### Fix 1.1: Add HSM Multi-Server Options to dsm.opt

**File to Modify:** `playbooks/petascale_configure.yml`  
**Line Range:** 704-719

**Current Code:**
```yaml
- name: Create dsm.opt configuration file for HSM client (Multi-Server)
  ansible.builtin.copy:
    dest: /opt/tivoli/tsm/client/hsm/bin/dsm.opt
    owner: root
    group: root
    mode: "0644"
    content: |
      *************************************************************
      * IBM Storage Protect HSM Client User Options File
      * Default server: {{ default_server }}
      *************************************************************

      SERVERNAME {{ default_server }}
  when:
    - hsm_client_bin_dir.stat.exists
    - hsm_multi_server_mode
```

**New Code:**
```yaml
- name: Create dsm.opt configuration file for HSM client (Multi-Server)
  ansible.builtin.copy:
    dest: /opt/tivoli/tsm/client/hsm/bin/dsm.opt
    owner: root
    group: root
    mode: "0644"
    content: |
      *************************************************************
      * IBM Storage Protect HSM Client User Options File
      * Multi-Server Configuration with Active Server Binding
      * Default server: {{ default_server }}
      *************************************************************

      SERVERNAME {{ default_server }}
      
      *************************************************************
      * HSM Multi-Server Options (REQUIRED for Active Server Binding)
      *************************************************************
      HSMMULTISERVER            YES
      HSMEXTOBJIDATTR           YES
      HSMENABLEIMMEDIATEMIGRATE YES
      HSMDISABLEAUTOMIGDAEMONS  YES
  when:
    - hsm_client_bin_dir.stat.exists
    - hsm_multi_server_mode
```

**Explanation:**
- `HSMMULTISERVER YES`: Enables multi-server mode
- `HSMEXTOBJIDATTR YES`: Creates `dmapi.IBMServ` attribute for binding
- `HSMENABLEIMMEDIATEMIGRATE YES`: Enables immediate migration
- `HSMDISABLEAUTOMIGDAEMONS YES`: Disables automatic migration (use policy-based)

---

### Fix 1.2: Add HSM Multiple-Server Setup Tasks

**File to Modify:** `playbooks/petascale_configure.yml`  
**Insert After:** Line 760 (after certificate import task)

**New Tasks to Add:**

```yaml
    - name: Check if HSM multiple-server environment is already configured
      ansible.builtin.shell: |
        dsmmigfs QUERYMultiserver /gpfs_main 2>&1 || echo "NOT_CONFIGURED"
      register: hsm_multiserver_check
      changed_when: false
      failed_when: false
      when:
        - hsm_client_bin_dir.stat.exists
        - hsm_multi_server_mode

    - name: Enable HSM multiple-server environment (First Time Setup)
      ansible.builtin.shell: |
        # Add management server (first server in list)
        dsmmigfs Add -Server={{ default_server }} /gpfs_main
        
        # Enable multi-server mode for all servers
        {% for server in sp_servers %}
        dsmmigfs ADDMultiserver -Server={{ server.name }} /gpfs_main
        {% endfor %}
      when:
        - hsm_client_bin_dir.stat.exists
        - hsm_multi_server_mode
        - "'NOT_CONFIGURED' in hsm_multiserver_check.stdout"
      register: hsm_multiserver_setup
      changed_when: true

    - name: Verify HSM multiple-server setup
      ansible.builtin.shell: |
        dsmmigfs QUERYMultiserver /gpfs_main
      when:
        - hsm_client_bin_dir.stat.exists
        - hsm_multi_server_mode
      register: hsm_multiserver_verify
      changed_when: false

    - name: Display HSM multiple-server verification
      ansible.builtin.debug:
        msg: |
          ============================================================
          HSM MULTIPLE-SERVER ENVIRONMENT VERIFICATION
          ============================================================
          {{ hsm_multiserver_verify.stdout }}
          ============================================================
      when:
        - hsm_client_bin_dir.stat.exists
        - hsm_multi_server_mode
```

**Explanation:**
- First checks if multi-server is already configured (idempotent)
- Adds management server using `dsmmigfs Add`
- Enables multi-server mode for all servers using `dsmmigfs ADDMultiserver`
- Verifies setup with `dsmmigfs QUERYMultiserver`

---

### Fix 1.3: Create Fileset-to-Server Mapping Documentation

**File to Modify:** `playbooks/petascale_configure.yml`  
**Insert After:** HSM multiple-server verification task

**New Task to Add:**

```yaml
    - name: Create fileset-to-server mapping documentation for disaster recovery
      ansible.builtin.copy:
        dest: /gpfs2/config/fileset_server_mapping_{{ inventory_hostname }}.txt
        owner: root
        group: root
        mode: "0644"
        content: |
          ============================================================
          FILESET-TO-SERVER MAPPING FOR DISASTER RECOVERY
          ============================================================
          Device: gpfs_main
          Host: {{ inventory_hostname }}
          Date: {{ ansible_date_time.iso8601 }}
          Configuration Mode: Multi-Server with Active Server Binding
          
          CRITICAL: This mapping must be preserved for disaster recovery!
          
          ============================================================
          FILESET MAPPING TABLE
          ============================================================
          {% for server in sp_servers %}
          
          Server Name    : {{ server.name }}
          Server Address : {{ server.address }}:{{ server.port }}
          Node Name      : {{ server.node_name }}
          Fileset Domain : {{ server.domain }}
          Backup Command : mmbackup {{ server.domain }}/ -t full --tsm-servers {{ server.name }} --scope inodespace
          Restore Command: dsmc restore {{ server.domain }}/ -subdir=yes -servername={{ server.name }}
          {% endfor %}
          
          ============================================================
          VERIFICATION COMMANDS
          ============================================================
          
          1. Verify active server binding for a file:
             dsmls <filename> | grep Srv
             mmlsattr -d -L <filename> | grep IBMServ
          
          2. List all files bound to a server:
             mmapplypolicy /gpfs_main -P rulefile --scope filesystem
          
          3. Query HSM multiple-server status:
             dsmmigfs QUERYMultiserver /gpfs_main
          
          ============================================================
          BACKUP WORKFLOW (Per Fileset)
          ============================================================
          {% for server in sp_servers %}
          
          # {{ server.domain }} -> {{ server.name }}
          mmcrsnapshot /dev/gpfs_main snap_{{ loop.index }} -j {{ server.domain | basename }}
          mmbackup {{ server.domain }}/ -t full -S snap_{{ loop.index }} \
            -s /gpfs2/log/mmbackup/gpfs_main/{{ server.domain | basename }} \
            -g /gpfs2/log/mmbackup/gpfs_main/{{ server.domain | basename }} \
            --tsm-servers {{ server.name }} --scope inodespace
          mmdelsnapshot /dev/gpfs_main snap_{{ loop.index }} -j {{ server.domain | basename }}
          {% endfor %}
          
          ============================================================
          END OF MAPPING DOCUMENTATION
          ============================================================
      when:
        - hsm_client_bin_dir.stat.exists
        - hsm_multi_server_mode

    - name: Display fileset-to-server mapping location
      ansible.builtin.debug:
        msg: |
          ============================================================
          DISASTER RECOVERY DOCUMENTATION CREATED
          ============================================================
          Location: /gpfs2/config/fileset_server_mapping_{{ inventory_hostname }}.txt
          
          IMPORTANT: Back up this file regularly!
          This mapping is critical for disaster recovery.
          ============================================================
      when:
        - hsm_client_bin_dir.stat.exists
        - hsm_multi_server_mode
```

**Explanation:**
- Creates comprehensive disaster recovery documentation
- Includes fileset-to-server mapping table
- Provides backup/restore commands for each fileset
- Includes verification commands
- Stores in `/gpfs2/config/` for easy backup

---

## Priority 2: BA Client Improvements

### Fix 2.1: Update BA Client DOMAIN to Use Fileset Paths

**File to Modify:** `playbooks/petascale_configure.yml`  
**Line Range:** 380-438

**Current Code (Multi-Server):**
```yaml
- name: Create dsm.sys configuration file for BA client (Multi-Server)
  ansible.builtin.copy:
    dest: /opt/tivoli/tsm/client/ba/bin/dsm.sys
    owner: root
    group: root
    mode: "0644"
    content: |
      *******************************************************************************
      * IBM Storage Protect BA Client System Options File
      * Multi-Server Configuration - Each server backs up different GPFS filesets
      *******************************************************************************
      {% for server in sp_servers %}
      
      SERVERNAME {{ server.name }}
        COMMMethod         TCPip
        TCPPort            {{ server.port }}
        TCPServeraddress   {{ server.address }}
        NODename           {{ server.node_name }}
        PASSWORDACCESS     PROMPT
        ERRORLOGNAME       /var/log/tsm/dsmerror.log
        SCHEDLOGNAME       /var/log/tsm/dsmsched.log
      {% if server.domain is defined and server.domain | length > 0 %}
        DOMAIN             {{ server.domain }}
      {% endif %}
      {% endfor %}
  when:
    - ba_client_bin_dir.stat.exists
    - ba_multi_server_mode
```

**Status:** ✅ **ALREADY CORRECT!**

The current code already uses `server.domain` which contains fileset paths like `/gpfs_main/fileset_2`. No changes needed!

---

### Fix 2.2: Add BA Client Manual Binding Documentation

**File to Modify:** `playbooks/petascale_configure.yml`  
**Insert After:** BA client configuration status display (around line 543)

**New Task to Add:**

```yaml
    - name: Create BA client manual binding guide
      ansible.builtin.copy:
        dest: /gpfs2/config/ba_client_manual_binding_guide_{{ inventory_hostname }}.txt
        owner: root
        group: root
        mode: "0644"
        content: |
          ============================================================
          BA CLIENT MANUAL FILESET-TO-SERVER BINDING GUIDE
          ============================================================
          Host: {{ inventory_hostname }}
          Date: {{ ansible_date_time.iso8601 }}
          
          IMPORTANT: BA clients (without HSM) cannot use automatic 
          active server binding. You MUST manually ensure filesets 
          are always backed up to the same server.
          
          ============================================================
          MANUAL BINDING PROCESS
          ============================================================
          
          1. Always use the -servername parameter when backing up
          2. Never change the server for a fileset once backups start
          3. Document which fileset goes to which server (see below)
          4. Use consistent backup commands (see examples below)
          
          ============================================================
          FILESET-TO-SERVER MAPPING
          ============================================================
          {% for server in sp_servers %}
          
          Server: {{ server.name }}
          Address: {{ server.address }}:{{ server.port }}
          Node Name: {{ server.node_name }}
          Fileset: {{ server.domain }}
          
          Backup Commands:
            # Incremental backup
            dsmc incremental {{ server.domain }} -servername={{ server.name }}
            
            # Selective backup
            dsmc selective {{ server.domain }}/* -servername={{ server.name }} -subdir=yes
            
            # Query backup
            dsmc query backup {{ server.domain }}/ -servername={{ server.name }} -subdir=yes
            
            # Restore
            dsmc restore {{ server.domain }}/ -servername={{ server.name }} -subdir=yes
          
          {% endfor %}
          ============================================================
          BEST PRACTICES
          ============================================================
          
          1. Create backup scripts that always use the correct server
          2. Never manually specify a different server for a fileset
          3. Document any changes to the mapping immediately
          4. Test restore procedures regularly
          5. Keep this guide updated and backed up
          
          ============================================================
          WARNING
          ============================================================
          
          If you accidentally back up a fileset to the wrong server:
          - The data will be on the wrong server
          - Restore operations will fail if you use the wrong server
          - You may need to re-backup the entire fileset to the correct server
          
          Always double-check the -servername parameter!
          
          ============================================================
          END OF BA CLIENT MANUAL BINDING GUIDE
          ============================================================
      when:
        - ba_client_bin_dir.stat.exists
        - ba_multi_server_mode

    - name: Display BA client manual binding guide location
      ansible.builtin.debug:
        msg: |
          ============================================================
          BA CLIENT MANUAL BINDING GUIDE CREATED
          ============================================================
          Location: /gpfs2/config/ba_client_manual_binding_guide_{{ inventory_hostname }}.txt
          
          IMPORTANT: BA clients cannot use automatic active server binding.
          Review this guide to understand manual binding procedures.
          ============================================================
      when:
        - ba_client_bin_dir.stat.exists
        - ba_multi_server_mode
```

**Explanation:**
- Documents that BA clients need manual binding enforcement
- Provides correct backup/restore commands for each fileset
- Includes best practices and warnings
- Helps prevent operator errors

---

## Priority 3: Operational Workflows

These are **OPTIONAL** enhancements that can be added later as separate playbooks.

### 3.1: Backup Playbook (Future)

**File to Create:** `playbooks/petascale_backup.yml`

**Purpose:**
- Automate snapshot creation
- Execute `mmbackup` with proper parameters
- Delete snapshots after backup
- Performance tuning and optimization

**Key Features:**
- Per-fileset backup execution
- Parallel backup support
- Performance monitoring
- Error handling and retry logic

---

### 3.2: Restore Playbook (Future)

**File to Create:** `playbooks/petascale_restore.yml`

**Purpose:**
- Query files from correct servers
- Execute restore operations
- Support parallel restore
- Validate restored data

**Key Features:**
- File list generation
- Wildcard-based restore
- Multi-node parallel restore
- Progress monitoring

---

### 3.3: Verification Playbook (Future)

**File to Create:** `playbooks/petascale_verify.yml`

**Purpose:**
- Verify active server binding
- Validate file-to-server mapping
- Health checks
- Compliance verification

**Key Features:**
- `dsmls` verification
- `mmlsattr` checks
- Policy engine validation
- Reporting

---

## Implementation Timeline

### Phase 1: Critical Fixes (MUST DO BEFORE PRODUCTION) 🔴

**Estimated Time:** 2-4 hours

1. **HSM Client dsm.opt Update** (30 minutes)
   - Modify `petascale_configure.yml` lines 704-719
   - Add HSM multi-server options
   - Test configuration file generation

2. **HSM Multiple-Server Setup Tasks** (1 hour)
   - Add new tasks after line 760
   - Test `dsmmigfs` commands
   - Verify multi-server environment

3. **Disaster Recovery Documentation** (30 minutes)
   - Add fileset-to-server mapping task
   - Test documentation generation
   - Verify file creation

4. **Testing & Validation** (1-2 hours)
   - Run playbook on test HSM client
   - Verify all configurations
   - Test backup/restore operations

**Deliverables:**
- ✅ Updated `petascale_configure.yml`
- ✅ HSM clients with active server binding enabled
- ✅ Disaster recovery documentation created
- ✅ Test results documented

---

### Phase 2: BA Client Improvements (RECOMMENDED) 🟡

**Estimated Time:** 1-2 hours

1. **BA Client Manual Binding Guide** (30 minutes)
   - Add documentation task
   - Test guide generation
   - Review content

2. **Testing & Validation** (30-60 minutes)
   - Run playbook on test BA client
   - Verify documentation
   - Test backup commands

**Deliverables:**
- ✅ BA client manual binding guide
- ✅ Test results documented

---

### Phase 3: Operational Workflows (OPTIONAL - FUTURE) 🟢

**Estimated Time:** 1-2 weeks (as needed)

1. **Backup Playbook** (3-5 days)
2. **Restore Playbook** (3-5 days)
3. **Verification Playbook** (2-3 days)

**Deliverables:**
- ✅ Automated backup workflows
- ✅ Automated restore workflows
- ✅ Verification and compliance tools

---

## Testing & Validation

### Pre-Implementation Checklist

Before implementing changes:

- [ ] Backup current `petascale_configure.yml`
- [ ] Review all code changes
- [ ] Prepare test environment
- [ ] Document current configuration
- [ ] Create rollback plan

---

### Post-Implementation Validation

#### HSM Client Validation

**1. Verify dsm.opt Configuration:**
```bash
cat /opt/tivoli/tsm/client/hsm/bin/dsm.opt | grep HSM
```

**Expected Output:**
```
HSMMULTISERVER            YES
HSMEXTOBJIDATTR           YES
HSMENABLEIMMEDIATEMIGRATE YES
HSMDISABLEAUTOMIGDAEMONS  YES
```

**2. Verify HSM Multiple-Server Setup:**
```bash
dsmmigfs QUERYMultiserver /gpfs_main
```

**Expected Output:**
```
Server Name          Bytes [KByte]        Files                Throughput [MByte/s]
---------------------------------------- -------------------- --------------------
PETASCALE-SP01       0                    0                    0
PETASCALE-SP03       0                    0                    0
```

**3. Test Active Server Binding:**
```bash
# Create a test file in fileset_2
echo "test" > /gpfs_main/fileset_2/test_binding.txt

# Backup to PETASCALE-SP01
dsmc incremental /gpfs_main/fileset_2/test_binding.txt -servername=PETASCALE-SP01

# Verify binding
dsmls /gpfs_main/fileset_2/test_binding.txt | grep Srv
mmlsattr -d -L /gpfs_main/fileset_2/test_binding.txt | grep IBMServ
```

**Expected Output:**
```
# dsmls output should show:
Srv: PETASCALE-SP01

# mmlsattr output should show:
dmapi.IBMServ: "PETASCALE-SP01"
```

**4. Test Binding Enforcement:**
```bash
# Try to backup to wrong server (should fail)
dsmc incremental /gpfs_main/fileset_2/test_binding.txt -servername=PETASCALE-SP03
```

**Expected:** Should fail with error indicating file is bound to different server

---

#### BA Client Validation

**1. Verify dsm.sys Configuration:**
```bash
cat /opt/tivoli/tsm/client/ba/bin/dsm.sys | grep -A 10 "SERVERNAME PETASCALE-SP01"
```

**Expected Output:**
```
SERVERNAME PETASCALE-SP01
  COMMMethod         TCPip
  TCPPort            1500
  TCPServeraddress   9.11.53.28
  NODename           ba-client-01-sp01
  PASSWORDACCESS     PROMPT
  ERRORLOGNAME       /var/log/tsm/dsmerror.log
  SCHEDLOGNAME       /var/log/tsm/dsmsched.log
  DOMAIN             /gpfs_main/fileset_1
```

**2. Test BA Client Backup:**
```bash
# Test backup to specific server
dsmc incremental /gpfs_main/fileset_1/ -servername=PETASCALE-SP01 -subdir=yes
```

**3. Verify Manual Binding Guide:**
```bash
cat /gpfs2/config/ba_client_manual_binding_guide_ba-client-01.txt
```

---

#### Documentation Validation

**1. Verify Disaster Recovery Documentation:**
```bash
cat /gpfs2/config/fileset_server_mapping_hsm-client-03.txt
```

**Expected:** Complete mapping table with all filesets and servers

**2. Backup Documentation Files:**
```bash
# Copy to safe location
cp /gpfs2/config/fileset_server_mapping_*.txt /backup/location/
cp /gpfs2/config/ba_client_manual_binding_guide_*.txt /backup/location/
```

---

## Disaster Recovery Documentation

### Critical Files to Backup

**Location:** `/gpfs2/config/`

**Files:**
1. `fileset_server_mapping_<hostname>.txt` - HSM client mapping
2. `ba_client_manual_binding_guide_<hostname>.txt` - BA client guide
3. `dsm.sys` - Client system options (backup from each client)
4. `dsm.opt` - Client user options (backup from each client)

**Backup Schedule:** Daily, with off-site copies

---

### Disaster Recovery Procedure

**Scenario:** Complete loss of GPFS filesystem

**Recovery Steps:**

1. **Restore GPFS Filesystem Structure**
   ```bash
   # Recreate filesets
   mmcrfileset gpfs_main fileset_1 -t /gpfs_main/fileset_1
   mmcrfileset gpfs_main fileset_2 -t /gpfs_main/fileset_2
   mmcrfileset gpfs_main fileset_3 -t /gpfs_main/fileset_3
   mmlinkfileset gpfs_main fileset_1 -J /gpfs_main/fileset_1
   mmlinkfileset gpfs_main fileset_2 -J /gpfs_main/fileset_2
   mmlinkfileset gpfs_main fileset_3 -J /gpfs_main/fileset_3
   ```

2. **Restore Client Configuration**
   ```bash
   # Copy backed-up dsm.sys and dsm.opt files
   cp /backup/dsm.sys /opt/tivoli/tsm/client/hsm/bin/
   cp /backup/dsm.opt /opt/tivoli/tsm/client/hsm/bin/
   ```

3. **Re-enable HSM Multiple-Server Environment**
   ```bash
   dsmmigfs Add -Server=PETASCALE-SP01 /gpfs_main
   dsmmigfs ADDMultiserver -Server=PETASCALE-SP01 /gpfs_main
   dsmmigfs ADDMultiserver -Server=PETASCALE-SP03 /gpfs_main
   ```

4. **Restore Data Using Mapping Documentation**
   ```bash
   # Refer to fileset_server_mapping_*.txt for correct server per fileset
   # Example for fileset_2 -> PETASCALE-SP01:
   dsmc restore /gpfs_main/fileset_2/ -servername=PETASCALE-SP01 -subdir=yes
   ```

5. **Verify Active Server Binding**
   ```bash
   # Check that restored files have correct binding
   dsmls /gpfs_main/fileset_2/* | grep Srv
   ```

---

## Summary of Changes

### Files to Modify

1. **`playbooks/petascale_configure.yml`**
   - Line 704-719: Update HSM dsm.opt with multi-server options
   - After line 760: Add HSM multiple-server setup tasks
   - After line 760: Add disaster recovery documentation task
   - After line 543: Add BA client manual binding guide task

### Files to Create

1. **`/gpfs2/config/fileset_server_mapping_<hostname>.txt`** (auto-generated)
   - Disaster recovery mapping documentation

2. **`/gpfs2/config/ba_client_manual_binding_guide_<hostname>.txt`** (auto-generated)
   - BA client manual binding procedures

### No Changes Required

1. **SP Server Configuration** - Already correct
2. **GPFS Fileset Structure** - Already perfect
3. **Multi-server configuration structure** - Already correct
4. **BA Client dsm.sys DOMAIN** - Already using fileset paths

---

## Risk Assessment

### Low Risk Changes ✅
- Adding HSM options to dsm.opt (non-breaking)
- Creating documentation files (informational only)
- Adding verification tasks (read-only)

### Medium Risk Changes 🟡
- Running `dsmmigfs` commands (one-time setup, can be re-run)
- Modifying existing tasks (well-tested, idempotent)

### High Risk Changes 🔴
- None identified

**Overall Risk:** **LOW** - All changes are additive and non-breaking

---

## Rollback Plan

If issues occur after implementation:

1. **Restore Original playbook:**
   ```bash
   cp petascale_configure.yml.backup petascale_configure.yml
   ```

2. **Remove HSM Multiple-Server Setup:**
   ```bash
   # If needed, can remove servers from multi-server environment
   dsmmigfs REMOVEMultiserver -Server=<SERVER_NAME> /gpfs_main
   ```

3. **Restore Original Configuration Files:**
   ```bash
   cp /backup/dsm.opt.backup /opt/tivoli/tsm/client/hsm/bin/dsm.opt
   ```

---

## Next Steps

### Immediate Actions (Before Implementation)

1. **Review this document thoroughly**
2. **Backup current configuration:**
   ```bash
   cp playbooks/petascale_configure.yml playbooks/petascale_configure.yml.backup
   cp /opt/tivoli/tsm/client/hsm/bin/dsm.opt /backup/dsm.opt.backup
   ```
3. **Prepare test environment**
4. **Schedule implementation window**

### Implementation Actions

1. **Implement Priority 1 fixes** (HSM Client Critical Fixes)
2. **Test thoroughly** (see Testing & Validation section)
3. **Implement Priority 2 improvements** (BA Client)
4. **Document results**
5. **Plan Priority 3 workflows** (if needed)

### Post-Implementation Actions

1. **Validate all configurations**
2. **Test backup/restore operations**
3. **Update operational procedures**
4. **Train operators on new workflows**
5. **Schedule regular verification checks**

---

## Conclusion

Your current implementation is **very close** to production-ready. The GPFS fileset structure is perfect, and the multi-server configuration structure is correct. The critical missing pieces are:

1. 🔴 **HSM multi-server options in dsm.opt** (5 lines of configuration)
2. 🔴 **HSM multiple-server setup commands** (3 commands to run once)
3. 🟡 **Disaster recovery documentation** (automated generation)

Once these are implemented, your Petascale multi-server environment will be fully compliant with IBM best practices and production-ready.

---

**Document End**

For questions or clarifications, please review the specific sections above or request additional details.