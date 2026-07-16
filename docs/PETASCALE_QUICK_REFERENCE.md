# Petascale Multi-Server HSM - Quick Reference Guide

**Last Updated:** June 22, 2026  
**Version:** 1.0

---

## Quick Links

- **Full Fix Plan:** [PETASCALE_AUTOMATION_FIX_PLAN.md](./PETASCALE_AUTOMATION_FIX_PLAN.md)
- **Implementation Plan:** [PETASCALE_IMPLEMENTATION_PLAN.md](./PETASCALE_IMPLEMENTATION_PLAN.md)
- **Design Document:** [design-peta-scale.md](./design/design-peta-scale.md)

---

## Critical Issues Found & Fixed

### 1. DMAPI Not Enabled ⚠️ CRITICAL

**Problem:** GPFS filesystem created without DMAPI support  
**Impact:** HSM operations fail with `ANS9086E dsmmigfs: A DMAPI error`

**Manual Fix:**
```bash
mmunmount gpfs_main
mmchfs gpfs_main -z yes
mmmount gpfs_main
dsmmigfs add /gpfs_main
```

**Automation Fix:** Phase 1 in fix plan (lines 167-220)

---

### 2. Firewall Port 1500 Closed ⚠️ CRITICAL

**Problem:** SP servers blocking port 1500  
**Impact:** Connection fails with `ANS1017E Session rejected: TCP/IP connection failure`

**Manual Fix:**
```bash
sudo firewall-cmd --add-port=1500/tcp
sudo firewall-cmd --permanent --add-port=1500/tcp
sudo firewall-cmd --reload
```

**Automation Fix:** Phase 2 in fix plan (lines 222-290)

---

### 3. SSL Certificates Not Imported ⚠️ HIGH

**Problem:** Certificates only imported for default server  
**Impact:** `ANS1592E An error occurred initializing the Trusted Services Library`

**Manual Fix:**
```bash
/opt/tivoli/tsm/client/ba/bin/dsmcert -add -server PETASCALE-SP01
/opt/tivoli/tsm/client/ba/bin/dsmcert -add -server PETASCALE-SP03
```

**Automation Fix:** Phase 3 in fix plan (lines 292-370)

---

### 4. Active Server Binding Not Set ⚠️ HIGH

**Problem:** `dmapi.IBMServ` attribute not set automatically  
**Impact:** Files not bound to specific servers, Petascale load distribution fails

**Manual Fix:**
```bash
# Method 1: mmputattr
/usr/lpp/mmfs/bin/mmputattr -k dmapi.IBMServ -v PETASCALE-SP01 /gpfs_main/fileset_2/file.txt

# Method 2: setfattr
setfattr -n user.dmapi.IBMServ -v PETASCALE-SP01 /gpfs_main/fileset_2/file.txt

# Method 3: GPFS Policy (best for automation)
cat > /tmp/policy.txt << 'EOF'
RULE 'BindToSP01'
  WHERE PATH_NAME LIKE '/gpfs_main/fileset_2/%'
  DO SET_DMATTR('dmapi.IBMServ', 'PETASCALE-SP01')
EOF
mmapplypolicy /gpfs_main -P /tmp/policy.txt -I defer
```

**Automation Fix:** Phase 4 in fix plan (lines 372-520)

---

### 5. Invalid TSM Commands ⚠️ MEDIUM

**Problem:** Playbook uses non-existent commands  
**Impact:** `ANS8001I Return code 3 (Command not found)`

**Invalid Commands:**
- `querymultiserver` - doesn't exist in TSM 8.2.0.0
- `dsmmigfs add -server=` - invalid parameter

**Manual Fix:**
```bash
# Remove querymultiserver references
# Change: dsmmigfs add /gpfs_main -server=SP01
# To:     dsmmigfs add /gpfs_main
```

**Automation Fix:** Phase 5 in fix plan (lines 522-580)

---

### 6. Configuration File Mismatch ⚠️ MEDIUM

**Problem:** BA and HSM dsm.sys files out of sync  
**Impact:** `ANS1036S The option 'PETASCALE-SP02' or the value supplied for it is not valid`

**Manual Fix:**
```bash
cp /opt/tivoli/tsm/client/hsm/bin/dsm.sys /opt/tivoli/tsm/client/ba/bin/dsm.sys
```

**Automation Fix:** Ensure both files created from same template

---

## Implementation Priority

### Phase 1: CRITICAL (Do First)
1. ✅ DMAPI enablement automation
2. ✅ Firewall port automation

### Phase 2: HIGH (Do Next)
3. ✅ Multi-server certificate import
4. ✅ Active server binding automation

### Phase 3: MEDIUM (Do After)
5. ✅ Remove invalid commands
6. ✅ Add comprehensive validation

---

## Key Configuration Files

### dsm.sys (Multi-Server)
**Location:** `/opt/tivoli/tsm/client/hsm/bin/dsm.sys`

```
SERVERNAME PETASCALE-SP01
  COMMMethod         TCPip
  TCPPort            1500
  TCPServeraddress   9.11.53.28
  NODename           hsm-client-03-sp01
  PASSWORDACCESS     GENERATE
  DOMAIN             /gpfs_main/fileset_2

SERVERNAME PETASCALE-SP03
  COMMMethod         TCPip
  TCPPort            1500
  TCPServeraddress   9.11.53.254
  NODename           hsm-client-03-sp03
  PASSWORDACCESS     GENERATE
  DOMAIN             /gpfs_main/fileset_3
```

### dsm.opt (HSM Multi-Server)
**Location:** `/opt/tivoli/tsm/client/hsm/bin/dsm.opt`

```
SERVERNAME                PETASCALE-SP01
HSMMULTISERVER            YES
HSMEXTOBJIDATTR           YES
HSMENABLEIMMEDIATEMIGRATE YES
HSMDISABLEAUTOMIGDAEMONS  YES
```

---

## Essential Commands

### DMAPI Management
```bash
# Check status
mmlsfs gpfs_main -z

# Enable
mmchfs gpfs_main -z yes

# Verify
mmlsfs gpfs_main -z | grep "yes"
```

### Firewall Management
```bash
# Open port
sudo firewall-cmd --add-port=1500/tcp
sudo firewall-cmd --permanent --add-port=1500/tcp

# Verify
sudo firewall-cmd --query-port=1500/tcp
```

### Certificate Management
```bash
# Import
/opt/tivoli/tsm/client/ba/bin/dsmcert -add -server PETASCALE-SP01

# List
/opt/tivoli/tsm/client/ba/bin/dsmcert -list

# Test
dsmc query session -servername=PETASCALE-SP01
```

### Active Server Binding
```bash
# Set attribute
/usr/lpp/mmfs/bin/mmputattr -k dmapi.IBMServ -v PETASCALE-SP01 /gpfs_main/fileset_2/file.txt

# Verify
/usr/lpp/mmfs/bin/mmlsattr -d -L /gpfs_main/fileset_2/file.txt | grep IBMServ
```

### HSM Operations
```bash
# Add filesystem
dsmmigfs add /gpfs_main

# Query status
dsmmigfs query /gpfs_main

# Migrate file
dsmmigrate /gpfs_main/fileset_2/file.txt

# Recall file
dsmrecall /gpfs_main/fileset_2/file.txt
```

---

## Validation Checklist

### Pre-Flight Checks
- [ ] GPFS installed and running
- [ ] DMAPI enabled on filesystem
- [ ] Firewall port 1500 open on all SP servers
- [ ] Network connectivity between client and servers
- [ ] TSM client packages installed

### Configuration Checks
- [ ] dsm.sys has all server stanzas
- [ ] dsm.opt has HSMMULTISERVER=YES
- [ ] Certificates imported for all servers
- [ ] Nodes registered on all servers
- [ ] Passwords set for all servers

### Operational Checks
- [ ] HSM filesystem management active
- [ ] Active server binding configured
- [ ] Test file migration works
- [ ] Test file recall works
- [ ] Shadow databases created

### Validation Commands
```bash
# Check configuration
grep -c "SERVERNAME" /opt/tivoli/tsm/client/hsm/bin/dsm.sys
grep "HSMMULTISERVER" /opt/tivoli/tsm/client/hsm/bin/dsm.opt

# Check HSM status
dsmmigfs query /gpfs_main

# Check DMAPI
mmlsfs gpfs_main -z

# Check connectivity
dsmc query session -servername=PETASCALE-SP01
dsmc query session -servername=PETASCALE-SP03

# Check binding
/usr/lpp/mmfs/bin/mmlsattr -d -L /gpfs_main/fileset_2/test.txt | grep IBMServ
```

---

## Troubleshooting Quick Guide

### Issue: "DMAPI error"
**Cause:** DMAPI not enabled  
**Fix:** `mmchfs gpfs_main -z yes && mmmount gpfs_main`

### Issue: "Session rejected: TCP/IP connection failure"
**Cause:** Firewall blocking port 1500  
**Fix:** `sudo firewall-cmd --add-port=1500/tcp`

### Issue: "SSL initialization error"
**Cause:** Certificate not imported  
**Fix:** `/opt/tivoli/tsm/client/ba/bin/dsmcert -add -server <SERVER>`

### Issue: "IBMServ attribute not set"
**Cause:** Active server binding not configured  
**Fix:** `/usr/lpp/mmfs/bin/mmputattr -k dmapi.IBMServ -v <SERVER> <file>`

### Issue: "Command not found: mmputattr"
**Cause:** GPFS bin not in PATH  
**Fix:** Use full path `/usr/lpp/mmfs/bin/mmputattr` or `export PATH=$PATH:/usr/lpp/mmfs/bin`

### Issue: "Server out of data storage space"
**Cause:** TSM server storage full  
**Fix:** Contact TSM admin to add storage

---

## Testing Workflow

### 1. Unit Test (Per Component)
```bash
# Test DMAPI
mmlsfs gpfs_main -z

# Test firewall
sudo firewall-cmd --query-port=1500/tcp

# Test certificates
/opt/tivoli/tsm/client/ba/bin/dsmcert -list

# Test connectivity
dsmc query session -servername=PETASCALE-SP01
```

### 2. Integration Test (End-to-End)
```bash
# Create test file
echo "test" > /gpfs_main/fileset_2/test.txt

# Set binding
/usr/lpp/mmfs/bin/mmputattr -k dmapi.IBMServ -v PETASCALE-SP01 /gpfs_main/fileset_2/test.txt

# Verify binding
/usr/lpp/mmfs/bin/mmlsattr -d -L /gpfs_main/fileset_2/test.txt | grep IBMServ

# Migrate
dsmmigrate /gpfs_main/fileset_2/test.txt

# Check status
ls -l /gpfs_main/fileset_2/test.txt

# Recall
dsmrecall /gpfs_main/fileset_2/test.txt
```

### 3. Validation Test
```bash
# Run validation playbook
ansible-playbook playbooks/petascale_configure.yml -i playbooks/inventory/petascale.ini --tags validate

# Check validation report
cat /gpfs_main/config/validation_report_*.txt
```

---

## Next Steps After Manual Testing

1. **Review Fix Plan:** Read [PETASCALE_AUTOMATION_FIX_PLAN.md](./PETASCALE_AUTOMATION_FIX_PLAN.md)
2. **Implement Phase 1:** DMAPI and Firewall automation
3. **Test Phase 1:** Verify on test environment
4. **Implement Phase 2:** Certificates and Active Binding
5. **Test Phase 2:** Verify multi-server setup
6. **Implement Phase 3:** Validation and cleanup
7. **Full Test:** Run complete playbook end-to-end
8. **Document:** Update user guide with any findings

---

## Important Notes

### Certificate Store Location
- **BA Client:** `/opt/tivoli/tsm/client/ba/bin/dsmcert`
- **HSM Client:** Shares BA client certificate store
- **Always use BA client path** for certificate operations

### GPFS Command Paths
- **Standard location:** `/usr/lpp/mmfs/bin/`
- **Add to PATH:** `export PATH=$PATH:/usr/lpp/mmfs/bin`
- **Or use full path:** `/usr/lpp/mmfs/bin/mmputattr`

### Active Server Binding Methods
1. **GPFS Policy** (best for automation) - Sets attribute automatically
2. **mmputattr** (GPFS command) - Manual per-file setting
3. **setfattr** (Linux command) - Fallback if mmputattr unavailable

### Multi-Server Configuration
- Each fileset backs up to different server
- `dmapi.IBMServ` attribute determines target server
- Shadow database created per fileset per server
- First backup requires `-t full` flag

---

## Contact & Support

**For Issues:**
1. Check this quick reference
2. Review full fix plan
3. Check validation report
4. Review TSM logs: `/var/log/tsm/dsmerror.log`
5. Check GPFS logs: `/var/adm/ras/mmfs.log.latest`

**Documentation:**
- Fix Plan: `docs/PETASCALE_AUTOMATION_FIX_PLAN.md`
- Implementation Plan: `docs/PETASCALE_IMPLEMENTATION_PLAN.md`
- Design Doc: `docs/design/design-peta-scale.md`

---

**Document End**