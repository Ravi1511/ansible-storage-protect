# Petascale Configure and Operations Guide

This guide covers all tested commands and workflows for configuring, validating, and operating the IBM Storage Protect Petascale deployment.

---

## Table of Contents

1. [petascale_configure.yml - All Supported Commands](#1-petascale_configureyml---all-supported-commands)
2. [Cleanup Scripts](#2-cleanup-scripts)
3. [Verification After Configuration](#3-verification-after-configuration)
4. [Policy Setting and Node Registration](#4-policy-setting-and-node-registration)
5. [dsmc Login Validation](#5-dsmc-login-validation)
6. [mmbackup Testing](#6-mmbackup-testing)

---

## 1. petascale_configure.yml - All Supported Commands

### Prerequisites

Before running any configure command:
- SP Servers installed and running
- BA/HSM clients installed
- Ansible inventory configured: `playbooks/inventory/petascale.ini`
- Host variables configured: `playbooks/host_vars/<hostname>.yml`

All commands are run from the project root:

```bash
cd /path/to/ansible-ibm-storage-protect-2
```

---

### 1.1 Configure Everything (All Servers and Clients)

Runs SP server configuration, BA client configuration, and HSM client configuration on all hosts in inventory.

```bash
ansible-playbook -i playbooks/inventory/petascale.ini \
  playbooks/petascale_configure.yml
```

---

### 1.2 Configure Only SP Servers

Skips BA and HSM client configuration.

```bash
ansible-playbook -i playbooks/inventory/petascale.ini \
  playbooks/petascale_configure.yml \
  -e "configure_clients=false"
```

---

### 1.3 Configure Only BA and HSM Clients

Skips SP server configuration.

```bash
ansible-playbook -i playbooks/inventory/petascale.ini \
  playbooks/petascale_configure.yml \
  -e "configure_servers=false"
```

---

### 1.4 Configure Only BA Clients

```bash
ansible-playbook -i playbooks/inventory/petascale.ini \
  playbooks/petascale_configure.yml \
  -e "configure_servers=false" \
  --tags ba_client_config
```

---

### 1.5 Configure Only HSM Clients

```bash
ansible-playbook -i playbooks/inventory/petascale.ini \
  playbooks/petascale_configure.yml \
  -e "configure_servers=false" \
  --tags hsm_client_config
```

---

### 1.6 Configure a Specific Server Only

Use `--limit` to target a single SP server.

```bash
ansible-playbook -i playbooks/inventory/petascale.ini \
  playbooks/petascale_configure.yml \
  --limit sp-server-01
```

For sp-server-02 / PETASCALE-SP03:

```bash
ansible-playbook -i playbooks/inventory/petascale.ini \
  playbooks/petascale_configure.yml \
  --limit sp-server-02
```

---

### 1.7 Configure a Specific Client Only

```bash
ansible-playbook -i playbooks/inventory/petascale.ini \
  playbooks/petascale_configure.yml \
  --limit hsm-client-03
```

---

### 1.8 Configure Specific Server and Skip Clients

```bash
ansible-playbook -i playbooks/inventory/petascale.ini \
  playbooks/petascale_configure.yml \
  -e "configure_clients=false" \
  --limit sp-server-01
```

---

### 1.9 Server Size Variants

The server size controls active log size and session limits.

| Size    | Active Log | Max Sessions |
|---------|-----------|-------------|
| xsmall  | 24 GB     | 75          |
| small   | 131 GB    | 250         |
| medium  | 131 GB    | 500         |
| large   | 524 GB    | 1000        |

To run configure with a specific server size:

```bash
# xsmall (lab/test)
ansible-playbook -i playbooks/inventory/petascale.ini \
  playbooks/petascale_configure.yml \
  -e "server_size=xsmall" \
  --limit sp-server-01

# small
ansible-playbook -i playbooks/inventory/petascale.ini \
  playbooks/petascale_configure.yml \
  -e "server_size=small" \
  --limit sp-server-01

# medium (default)
ansible-playbook -i playbooks/inventory/petascale.ini \
  playbooks/petascale_configure.yml \
  -e "server_size=medium"

# large (petascale production)
ansible-playbook -i playbooks/inventory/petascale.ini \
  playbooks/petascale_configure.yml \
  -e "server_size=large"
```

---

### 1.10 Dry Run (Check Mode)

Validates what would change without making any actual changes.

```bash
ansible-playbook -i playbooks/inventory/petascale.ini \
  playbooks/petascale_configure.yml \
  --check
```

---

## 2. Cleanup Scripts

All cleanup scripts are under `scripts/`. Run them from that directory:

```bash
cd /path/to/ansible-ibm-storage-protect-2/scripts
```

---

### 2.1 Cleanup Everything

Cleans SP servers, HSM clients, and BA clients completely.

```bash
./cleanup_all.sh ../playbooks/inventory/petascale.ini
```

**Options:**

| Option              | What it does                          |
|---------------------|---------------------------------------|
| `--disable-dmapi`   | Disables DMAPI on GPFS filesystem     |
| `--remove-testdata` | Removes test data from GPFS filesets  |
| `--skip-sp-servers` | Skips SP server cleanup               |
| `--skip-hsm-clients`| Skips HSM client cleanup              |
| `--skip-ba-clients` | Skips BA client cleanup               |

```bash
# Clean everything including DMAPI disable
./cleanup_all.sh ../playbooks/inventory/petascale.ini --disable-dmapi

# Clean everything including test data removal
./cleanup_all.sh ../playbooks/inventory/petascale.ini --remove-testdata

# Clean only SP servers (skip clients)
./cleanup_all.sh ../playbooks/inventory/petascale.ini --skip-hsm-clients --skip-ba-clients

# Clean only clients (skip SP servers)
./cleanup_all.sh ../playbooks/inventory/petascale.ini --skip-sp-servers
```

---

### 2.2 Cleanup HSM Clients Only

```bash
./cleanup_hsm_clients.sh ../playbooks/inventory/petascale.ini
```

**Options:**

| Option               | What it does                         |
|----------------------|--------------------------------------|
| `--disable-dmapi`    | Disables DMAPI on GPFS filesystem    |
| `--remove-testdata`  | Removes test data from GPFS filesets |

```bash
# With DMAPI disable
./cleanup_hsm_clients.sh ../playbooks/inventory/petascale.ini --disable-dmapi

# With test data removal
./cleanup_hsm_clients.sh ../playbooks/inventory/petascale.ini --remove-testdata
```

**What it cleans:**
- HSM client RPM packages (`TIVsm-HSM`)
- HSM configuration files (`dsm.sys`, `dsm.opt`)
- SSL certificate files (`dsmcert.kdb`, `dsmcert.sth`, `dsmcert.rdb`)
- TSM log files
- Generated password cache files (`TSM.PWD`, `tsm.pwd`)

---

### 2.3 Cleanup BA Clients Only

```bash
./cleanup_ba_clients.sh ../playbooks/inventory/petascale.ini
```

**What it cleans:**
- BA client configuration files (`dsm.sys`, `dsm.opt`)
- SSL certificate files (`dsmcert.kdb`, `dsmcert.sth`, `dsmcert.rdb`)
- TSM log files (`dsmerror.log`, `dsmsched.log`)
- Generated password cache files (`TSM.PWD`, `tsm.pwd`)

---

### 2.4 SP Server Pool Directory Prep (on SP server itself)

Run this on the SP server before defining a storage pool directory.

```bash
./create_sp_server_storage_dir.sh
```

Override the directory path:

```bash
STGPOOL_DIR=/tmp/data ./create_sp_server_storage_dir.sh
```

**Must be run as root on the SP server directly.**

---

## 3. Verification After Configuration

### 3.1 Run Petascale Configuration Validator

Runs a comprehensive set of checks against a specific HSM client.

```bash
./validate_petascale_config.sh hsm-client-03
```

**What it validates:**
- Configuration files exist
- SSH connectivity to HSM client
- GPFS installed and running
- DMAPI enabled on GPFS filesystem
- SP server connectivity (port 1500)
- SSL certificates imported
- Storage pool defined and accessible
- Policy domain configured
- Node registered

---

### 3.2 Verify BA Client Configuration Files

SSH to the BA/HSM client and check:

```bash
ssh root@p9d-vm4.storage.tucson.ibm.com

# Check dsm.sys exists and looks correct
cat /opt/tivoli/tsm/client/ba/bin/dsm.sys

# Check dsm.opt
cat /opt/tivoli/tsm/client/ba/bin/dsm.opt

# Check HSM dsm.sys
cat /opt/tivoli/tsm/client/hsm/bin/dsm.sys

# Check log files created
ls -la /var/log/tsm/
```

Expected `dsm.sys` structure (multi-server):

```
SERVERNAME PETASCALE-SP01
  COMMMethod         TCPip
  TCPPort            1500
  TCPServeraddress   9.11.53.28
  NODename           hsm-client-03-sp01
  PASSWORDACCESS     GENERATE
  ERRORLOGNAME       /var/log/tsm/dsmerror_petascale-sp01.log
  SCHEDLOGNAME       /var/log/tsm/dsmsched_petascale-sp01.log
  DOMAIN             /gpfs_main/fileset_2

SERVERNAME PETASCALE-SP03
  COMMMethod         TCPip
  TCPPort            1500
  TCPServeraddress   9.11.53.254
  NODename           hsm-client-03-sp03
  PASSWORDACCESS     GENERATE
  ERRORLOGNAME       /var/log/tsm/dsmerror_petascale-sp03.log
  SCHEDLOGNAME       /var/log/tsm/dsmsched_petascale-sp03.log
  DOMAIN             /gpfs_main/fileset_3
```

---

### 3.3 Verify SSL Certificates Imported

```bash
gsk8capicmd_64 -cert -list \
  -db /opt/tivoli/tsm/client/ba/bin/dsmcert.kdb \
  -stashed
```

Expected output shows both server certificates:

```
! "TSM server PETASCALE-SP01 self-signed key"
! "TSM server PETASCALE-SP03 self-signed key"
```

---

### 3.4 Verify Nodes on SP Server

From the BA/HSM client machine using `dsmadmc`:

```bash
dsmadmc -se=PETASCALE-SP01 -id=admin -pa='admin@@123456789'
```

Inside `dsmadmc`:

```
q node
q stgpool
q domain GPFS_DOMAIN
```

---

## 4. Policy Setting and Node Registration

All commands below run on the **client machine** where `dsmadmc` is installed.

### 4.1 Bootstrap Scripts

These scripts automate storage pool, policy domain, management class, and node registration on an already configured and running SP server.

#### For PETASCALE-SP01

Run from the client host:

```bash
cd /path/to/ansible-ibm-storage-protect-2/scripts
chmod +x gpfs_policy_node_bootstrap.sh
./gpfs_policy_node_bootstrap.sh
```

**Defaults:**
- Server alias: `PETASCALE-SP01`
- Storage pool: `GPFSPOOL`
- Storage pool directory: `/tmp/data`
- Policy domain: `GPFS_DOMAIN`
- Policy set: `STANDARD`
- Management class: `GPFS_DAILY`
- Node: `hsm-client-03-sp01`

#### For PETASCALE-SP03

```bash
chmod +x gpfs_policy_node_bootstrap_sp03.sh
./gpfs_policy_node_bootstrap_sp03.sh
```

**Defaults:**
- Server alias: `PETASCALE-SP03`
- Node: `hsm-client-03-sp03`
- All other settings same as SP01

#### Override any value at runtime

```bash
SERVER_NAME=PETASCALE-SP03 \
NODE_NAME=hsm-client-03-sp03 \
STGPOOL_DIR=/tmp/data \
./gpfs_policy_node_bootstrap.sh
```

---

### 4.2 What the Bootstrap Scripts Create

In order, each script creates on the SP server:

1. Storage pool directory on SP server filesystem
2. `DEFINE STGPOOL GPFSPOOL stgtype=directory maxsize=100G`
3. `DEFINE STGPOOLDIRECTORY GPFSPOOL /tmp/data`
4. `DEFINE DOMAIN GPFS_DOMAIN description="GPFS Filesets Backup Domain"`
5. `DEFINE POLICYSET GPFS_DOMAIN STANDARD`
6. `DEFINE MGMTCLASS GPFS_DOMAIN STANDARD GPFS_DAILY description="Daily GPFS backup"`
7. `DEFINE COPYGROUP GPFS_DOMAIN STANDARD GPFS_DAILY type=backup destination=GPFSPOOL verexists=30 verdeleted=60 retextra=30 retonly=90`
8. `ASSIGN DEFMGMTCLASS GPFS_DOMAIN STANDARD GPFS_DAILY`
9. `VALIDATE POLICYSET GPFS_DOMAIN STANDARD`
10. `ACTIVATE POLICYSET GPFS_DOMAIN STANDARD` (responds `y` automatically)
11. `REGISTER NODE <node_name> <password> domain=GPFS_DOMAIN maxnummp=4 compression=YES deduplication=CLIENTORSERVER`

**All steps are idempotent** - safe to rerun.

---

### 4.3 Storage Pool Directory Preparation (on SP server)

Before running the bootstrap script, ensure the directory exists on the SP server.

SSH to the SP server:

```bash
ssh onecloud-user@9.11.53.28
sudo su -
chmod +x /tmp/create_sp_server_storage_dir.sh
/tmp/create_sp_server_storage_dir.sh
```

or manually:

```bash
mkdir -p /tmp/data
chown tsminst1:tsmusers /tmp/data
chmod 0755 /tmp/data
```

---

## 5. dsmc Login Validation

After policy setup and node registration, validate that the client can authenticate to each SP server.

### 5.1 Important Notes

- `PASSWORDACCESS GENERATE` is required for non-interactive tools like `mmbackup`
- `PASSWORDACCESS PROMPT` is useful for manual testing but breaks `mmbackup`
- The recommended state for production is `GENERATE`
- First login after fresh node registration must be done interactively to initialize the generated password cache

### 5.2 Required: Clear Stale Password Cache Before First Login

```bash
rm -f /opt/tivoli/tsm/client/ba/bin/TSM.PWD
rm -f /opt/tivoli/tsm/client/ba/bin/tsm.pwd
rm -f /opt/tivoli/tsm/client/hsm/bin/TSM.PWD
rm -f /opt/tivoli/tsm/client/hsm/bin/tsm.pwd
```

### 5.3 Login to PETASCALE-SP01

```bash
dsmc query session -servername=PETASCALE-SP01
```

Prompts:
- User id: `hsm-client-03-sp01` (or press Enter for default)
- Password: `P9dVm4Password@@123`

Expected successful output:

```
Session established with server SERVER1: Linux/x86_64
  Server Version 8, Release 1, Level 27.000
  ...
Node Name...............: HSM-CLIENT-03-SP01
User Name...............: root
SSL Information.........: TLSv1.3 TLS_AES_256_GCM_SHA384
```

### 5.4 Login to PETASCALE-SP03

```bash
dsmc query session -servername=PETASCALE-SP03
```

Prompts:
- User id: `hsm-client-03-sp03` (or press Enter for default)
- Password: `P9dVm4Password@@123`

### 5.5 If Node Gets Locked

A node gets locked if too many failed password attempts occur. Fix it by running inside `dsmadmc`:

```bash
dsmadmc -se=PETASCALE-SP01 -id=admin -pa='admin@@123456789'
```

Then:

```
unlock node HSM-CLIENT-03-SP01
q node HSM-CLIENT-03-SP01
quit
```

Then clear password cache and retry `dsmc query session`.

---

## 6. mmbackup Testing

After both SP servers have successful `dsmc query session` logins, run `mmbackup` tests.

### 6.1 Validate mmbackup Client Access

GPFS provides its own test command. Run this before mmbackup:

```bash
env LD_LIBRARY_PATH= /opt/tivoli/tsm/client/ba/bin/dsmc -servername=PETASCALE-SP01
```

If this command starts and prompts for credentials (or exits cleanly), the client is usable by mmbackup.

---

### 6.2 Full Backup to PETASCALE-SP01

Backup `fileset_2` to SP01:

```bash
/usr/lpp/mmfs/bin/mmbackup /gpfs_main/fileset_2 \
  --scope inodespace \
  --tsm-servers PETASCALE-SP01 \
  -t full
```

Expected successful output:

```
mmbackup: Backup of /gpfs_main/fileset_2 begins at ...
mmbackup: Scanning fileset gpfs_main.fileset_2
mmbackup: Fileset scan of gpfs_main.fileset_2 is complete.
mmbackup: Calculating backup and expire lists for server PETASCALE-SP01
mmbackup: Sending files to the TSM server [N changed, 0 expired].
mmbackup: Backup of /gpfs_main/fileset_2 completed successfully at ...
```

---

### 6.3 Full Backup to PETASCALE-SP03

Backup `fileset_3` to SP03:

```bash
/usr/lpp/mmfs/bin/mmbackup /gpfs_main/fileset_3 \
  --scope inodespace \
  --tsm-servers PETASCALE-SP03 \
  -t full
```

---

### 6.4 Use the Automated Backup Script

```bash
cd /path/to/ansible-ibm-storage-protect-2/scripts
./trigger_gpfs_backup.sh hsm-client-03
```

This script:
- reads fileset-to-server mappings from `host_vars/hsm-client-03.yml`
- connects to the HSM client
- runs `mmbackup` for each configured fileset
- reports success or failure per fileset

To test a single fileset only:

```bash
./trigger_gpfs_backup.sh hsm-client-03 /gpfs_main/fileset_2
```

---

### 6.5 Incremental Backup

After a full backup, run incremental:

```bash
/usr/lpp/mmfs/bin/mmbackup /gpfs_main/fileset_2 \
  --scope inodespace \
  --tsm-servers PETASCALE-SP01
```

Note: Without `-t full`, mmbackup runs incremental by default.

---

### 6.6 Verify Backup on SP Server

From `dsmadmc`:

```bash
dsmadmc -se=PETASCALE-SP01 -id=admin -pa='admin@@123456789'
```

Inside `dsmadmc`:

```
q stgpool GPFSPOOL f=d
q actlog search=BACKUP begindate=today
q node hsm-client-03-sp01 f=d
```

---

### 6.7 Common mmbackup Errors and Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `Unable to get TSM Client Version information` | `dsmc` not working non-interactively | Clear password cache, reinitialize login with GENERATE mode |
| `Configuration file dsm.sys is missing` | `dsm.sys` was deleted or not created | Rerun `petascale_configure.yml` |
| `No inventory found in TSM server` | Running incremental when no full backup exists | Run with `-t full` first |
| `Some dsmc backup jobs failed with return code 12` | Node not registered or fileset domain mismatch | Check node registration and domain in `dsm.sys` |
| `Session Rejected: node is currently locked` | Failed password attempts locked the node | Unlock with `dsmadmc`, clear `TSM.PWD`, retry |
| `ANS1593E Cannot open the key database` | SSL cert database missing or corrupt | Reimport certs with `dsmcert -add -server` |

---

## Summary: Full Lab Test Sequence

This is the complete tested sequence from fresh install to successful `mmbackup`.

```
1. Configure SP servers
   ansible-playbook -i playbooks/inventory/petascale.ini playbooks/petascale_configure.yml --limit sp_servers

2. Configure HSM and BA clients
   ansible-playbook -i playbooks/inventory/petascale.ini playbooks/petascale_configure.yml --limit hsm_clients --tags hsm_client_config

3. Create storage pool directory on SP server (run on SP server)
   /tmp/create_sp_server_storage_dir.sh

4. Bootstrap policy and register nodes on SP01 (run on client)
   ./scripts/gpfs_policy_node_bootstrap.sh

5. Bootstrap policy and register nodes on SP03 (run on client)
   ./scripts/gpfs_policy_node_bootstrap_sp03.sh

6. Clear password cache (run on client)
   rm -f /opt/tivoli/tsm/client/ba/bin/TSM.PWD
   rm -f /opt/tivoli/tsm/client/hsm/bin/TSM.PWD

7. Validate dsmc login on SP01 (run on client)
   dsmc query session -servername=PETASCALE-SP01

8. Validate dsmc login on SP03 (run on client)
   dsmc query session -servername=PETASCALE-SP03

9. Validate full configuration
   ./scripts/validate_petascale_config.sh hsm-client-03

10. Run mmbackup fileset_2 to SP01 (run on client)
    /usr/lpp/mmfs/bin/mmbackup /gpfs_main/fileset_2 --scope inodespace --tsm-servers PETASCALE-SP01 -t full

11. Run mmbackup fileset_3 to SP03 (run on client)
    /usr/lpp/mmfs/bin/mmbackup /gpfs_main/fileset_3 --scope inodespace --tsm-servers PETASCALE-SP03 -t full
```
