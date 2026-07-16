# SP Server Package Path Standardization

## Overview

This document describes the enhancement to SP Server installation that adds support for explicit package paths, making it consistent with BA Client and HSM Client implementations.

## Problem Statement

Previously, SP Server installation used pattern matching to find installation packages:

```yaml
sp_server_version: "8.1.27.000"
sp_server_bin_repo: "/tmp"
# Searches for: /tmp/8.1.27.000*.bin
```

**Issues:**
- Ambiguous when multiple packages with same version exist
- No control over which file is selected
- Inconsistent with BA Client approach
- Difficult to troubleshoot

## Solution

Added support for explicit package paths while maintaining backward compatibility:

```yaml
# NEW: Explicit path (recommended)
sp_server_package_path: "/tmp/8.1.27.000-IBM-SPSRV-LinuxX86_64.bin"

# OLD: Pattern matching (still supported)
sp_server_version: "8.1.27.000"
sp_server_bin_repo: "/tmp"
```

## Implementation Details

### Files Modified

1. **roles/sp_server_install/tasks/sp_server_prechecks_linux.yml**
   - Added explicit package path check (lines 278-310)
   - Enhanced pattern matching with warnings (lines 312-365)
   - Improved error messages

2. **playbooks/host_vars/sp-server-01.yml**
   - Updated to use explicit package path
   - Added documentation comments

3. **playbooks/host_vars/sp-server-02.yml**
   - Updated to use explicit package path
   - Added documentation comments

4. **playbooks/host_vars/sp-server-03.yml**
   - Updated to use explicit package path
   - Added documentation comments

5. **playbooks/host_vars/README.md**
   - Added package location documentation
   - Explained both methods
   - Updated examples

### Logic Flow

```
1. Check if sp_server_package_path is defined
   ├─ YES: Check if file exists
   │   ├─ YES: Use explicit path ✓
   │   └─ NO: Fail with clear error message
   │
   └─ NO: Fall back to pattern matching (legacy)
       ├─ Search for {{ sp_server_version }}*.bin
       ├─ Warn if multiple files found
       └─ Use first match
```

## Benefits

### ✅ Advantages

1. **No Ambiguity** - Exact file specified, no guessing
2. **Consistency** - Same approach as BA Client and HSM Client
3. **Backward Compatible** - Existing configurations continue to work
4. **Clear Errors** - Immediate feedback if file not found
5. **Better Control** - User explicitly chooses which package to install
6. **Easier Troubleshooting** - No pattern matching confusion

### ⚠️ Considerations

1. **Migration** - Users can migrate gradually (not required immediately)
2. **Documentation** - Users need to know about new option
3. **Variable Precedence** - Explicit path takes precedence over pattern matching

## Usage Examples

### Installation with Explicit Path

```yaml
# playbooks/host_vars/sp-server-01.yml
sp_server_version: "8.1.27.000"
sp_server_state: "present"
sp_server_action: "install"
sp_server_package_path: "/tmp/8.1.27.000-IBM-SPSRV-LinuxX86_64.bin"
```

### Upgrade with Explicit Path

```yaml
# playbooks/host_vars/sp-server-01.yml
sp_server_version: "8.2.2.000"
sp_server_state: "upgrade"
sp_server_action: "upgrade"
sp_server_package_path: "/tmp/8.2.2.000-IBM-SPSRV-LinuxX86_64.bin"
```

### Legacy Pattern Matching (Still Supported)

```yaml
# playbooks/host_vars/sp-server-01.yml
sp_server_version: "8.1.27.000"
sp_server_state: "present"
sp_server_action: "install"
sp_server_bin_repo: "/tmp"
```

## Error Messages

### Explicit Path Not Found

```
============================================================
SP Server Package Not Found
============================================================

ERROR: The specified SP Server package does not exist.

Specified path: /tmp/8.1.27.000-IBM-SPSRV-LinuxX86_64.bin
Host: sp-server-01

Please verify:
1. The file exists on the remote host
2. The path is correct
3. You have read permissions

To check on the remote host:
  ls -la /tmp/8.1.27.000-IBM-SPSRV-LinuxX86_64.bin
============================================================
```

### Pattern Matching - No Files Found

```
============================================================
SP Server Package Not Found (Pattern Matching)
============================================================

ERROR: No SP Server binary found matching the pattern.

Search pattern: 8.1.27.000*.bin
Search directory: /tmp
Host: sp-server-01

Please verify:
1. The binary file exists in the specified directory
2. The version number is correct
3. The file name matches the pattern

To check on the remote host:
  ls -la /tmp/8.1.27.000*.bin

TIP: For better control, use explicit package path instead:
  sp_server_package_path: "/tmp/8.1.27.000-IBM-SPSRV-LinuxX86_64.bin"
============================================================
```

### Pattern Matching - Multiple Files Found

```
WARNING: Multiple SP Server binaries found matching pattern 8.1.27.000*.bin
Using first match: /tmp/8.1.27.000-IBM-SPSRV-LinuxX86_64.bin

All matches found:
  - /tmp/8.1.27.000-IBM-SPSRV-LinuxX86_64.bin
  - /tmp/8.1.27.000-IBM-SPSRV-LinuxX86_64-DEBUG.bin

RECOMMENDATION: Use explicit package path to avoid ambiguity:
  sp_server_package_path: "/tmp/8.1.27.000-IBM-SPSRV-LinuxX86_64.bin"
```

## Migration Guide

### For New Deployments

Use explicit package paths from the start:

```yaml
sp_server_package_path: "/tmp/8.1.27.000-IBM-SPSRV-LinuxX86_64.bin"
```

### For Existing Deployments

**Option 1: Migrate Immediately (Recommended)**

Update your host_vars files to use explicit paths:

```bash
# Edit each SP Server host_vars file
vi playbooks/host_vars/sp-server-01.yml

# Change from:
sp_server_bin_repo: "/tmp"

# To:
sp_server_package_path: "/tmp/8.1.27.000-IBM-SPSRV-LinuxX86_64.bin"
```

**Option 2: Migrate Gradually**

Keep using pattern matching for now, migrate during next upgrade cycle.

## Testing

### Test Explicit Path

```bash
# Test with explicit path
ansible-playbook playbooks/sp_server_install_playbook.yml \
  -i playbooks/inventory/petascale.ini \
  --limit sp-server-01 \
  --check
```

### Test Pattern Matching (Legacy)

```bash
# Remove sp_server_package_path from host_vars
# Test with pattern matching
ansible-playbook playbooks/sp_server_install_playbook.yml \
  -i playbooks/inventory/petascale.ini \
  --limit sp-server-01 \
  --check
```

### Verify Package Discovery

```bash
# Check which package will be used
ansible-playbook playbooks/sp_server_install_playbook.yml \
  -i playbooks/inventory/petascale.ini \
  --limit sp-server-01 \
  --tags prechecks \
  -v
```

## Comparison with Other Components

| Component | Package Path Variable | Pattern Matching |
|-----------|----------------------|------------------|
| BA Client | `ba_client_package_path` | Not supported |
| HSM Client | `hsm_client_package_path` | Supported (fallback) |
| SP Server | `sp_server_package_path` | Supported (fallback) |

**Consistency achieved:** All components now support explicit package paths as the primary method.

## Change Summary

- **Type:** Enhancement (backward compatible)
- **Scope:** Minor change
- **Files Modified:** 5
- **Lines Changed:** ~150
- **Testing Required:** Yes (both methods)
- **Documentation Updated:** Yes
- **Breaking Changes:** None

## Recommendations

1. ✅ **Use explicit package paths** for all new deployments
2. ✅ **Migrate existing deployments** during next maintenance window
3. ✅ **Update documentation** to reflect new best practice
4. ✅ **Test both methods** to ensure backward compatibility
5. ✅ **Monitor for warnings** about multiple files found

## Support

For questions or issues:
1. Review this document
2. Check `playbooks/host_vars/README.md`
3. Review example files in `playbooks/host_vars/`
4. Consult Ansible variable precedence documentation

---

**Document Version:** 1.0  
**Last Updated:** 2026-05-25  
**Author:** Bob (AI Assistant)