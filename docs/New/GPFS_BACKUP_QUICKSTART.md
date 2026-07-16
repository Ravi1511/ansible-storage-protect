# GPFS Backup Quick Start Guide

## Prerequisites Checklist

- [ ] SP Server `PETASCALE-SP02` at `9.11.53.254` is running
- [ ] GPFS filesystem `gpfs_main` is mounted on `p9d-vm4`
- [ ] Network connectivity between p9d-vm4 and SP Server
- [ ] BA Client package available: `8.1.27.0-TIV-TSMBAC-LinuxX86.tar`

## Quick Setup (30 Minutes)

### Step 1: Configure SP Server (10 minutes)

```bash
# SSH to SP Server
ssh root@9.11.53.254

# Connect to admin console
dsmadmc -id=admin -password=admin@@123456789

# Create storage pool
DEFINE STGPOOL GPFSPOOL POOLTYPE=DIRECTORY MAXSIZE=100G
DEFINE VOLUME GPFSPOOL /data/tsmpool/gpfs FORMATSIZE=50G

# Create policy domain
DEFINE DOMAIN GPFS_DOMAIN DESCRIPTION='GPFS Filesets Backup Domain'
DEFINE MGMTCLASS GPFS_DOMAIN STANDARD GPFS_DAILY DESCRIPTION='Daily backup for GPFS filesets'
DEFINE COPYGROUP GPFS_DOMAIN STANDARD GPFS_DAILY TYPE=BACKUP DESTINATION=GPFSPOOL VEREXISTS=30 VERDELETED=60
ASSIGN DEFMGMTCLASS GPFS_DOMAIN STANDARD GPFS_DAILY
VALIDATE POLICYSET GPFS_DOMAIN STANDARD
ACTIVATE POLICYSET GPFS_DOMAIN STANDARD

# Register node
REGISTER NODE P9D-VM4 P9dVm4Password@@123 DOMAIN=GPFS_DOMAIN MAXNUMMP=4 DEDUPLICATION=CLIENTORSERVER COMPRESSION=YES
GRANT AUTHORITY P9D-VM4 CLASSES=CLIENT

# Exit
quit
```

### Step 2: Install BA Client (10 minutes)

```bash
# Copy package to p9d-vm4
scp /path/to/8.1.27.0-TIV-TSMBAC-LinuxX86.tar root@p9d-vm4.storage.tucson.ibm.com:/tmp/

# Using Ansible (recommended)
cd ansible-ibm-storage-protect-2
ansible-playbook -i playbooks/inventory/petascale.ini \
  playbooks/ba_client_install/playbooks/linux/ba_client_install_playbook.yml \
  --limit p9d-vm4

# OR Manual installation
ssh root@p9d-vm4.storage.tucson.ibm.com
cd /tmp
tar -xvf 8.1.27.0-TIV-TSMBAC-LinuxX86.tar
./install.sh
```

### Step 3: Configure BA Client (5 minutes)

```bash
# SSH to p9d-vm4
ssh root@p9d-vm4.storage.tucson.ibm.com

# Create configuration
cat > /opt/tivoli/tsm/client/ba/bin/dsm.sys << 'EOF'
SERVERNAME      PETASCALE-SP02
TCPSERVERADDRESS    9.11.53.254
TCPPORT             1500
NODENAME            P9D-VM4
COMMMETHOD          TCPIP
COMPRESSION         YES
DEDUPLICATION       YES
ERRORLOGNAME        /var/log/tsm/dsmerror.log
SCHEDLOGNAME        /var/log/tsm/dsmsched.log
SUBDIR              YES
DOMAIN              /gpfs_main/testfs
DOMAIN              /gpfs_main/fileset_1
DOMAIN              /gpfs_main/fileset_2
DOMAIN              /gpfs_main/fileset_3
INCLUDE             /gpfs_main/testfs/.../*
INCLUDE             /gpfs_main/fileset_1/.../*
INCLUDE             /gpfs_main/fileset_2/.../*
INCLUDE             /gpfs_main/fileset_3/.../*
EOF

# Create log directory
mkdir -p /var/log/tsm

# Set password
dsmc set password P9dVm4Password@@123 P9dVm4Password@@123

# Test connection
dsmc query session
```

### Step 4: Test Backup (5 minutes)

```bash
# Create test files
echo "Test" > /gpfs_main/testfs/test1.txt

# Run backup
dsmc incremental /gpfs_main/testfs -subdir=yes

# Verify
dsmc query backup /gpfs_main/testfs/.../*
```

### Step 5: Setup Automated Backups (5 minutes)

```bash
# On SP Server
dsmadmc -id=admin -password=admin@@123456789

# Create daily schedule
DEFINE SCHEDULE GPFS_DOMAIN DAILY_GPFS_BACKUP \
  ACTION=INCREMENTAL \
  STARTDATE=TODAY \
  STARTTIME=02:00 \
  DURATION=4 \
  DURUNITS=HOURS \
  PERIOD=1 \
  PERUNITS=DAYS \
  OBJECTS='/gpfs_main/testfs /gpfs_main/fileset_1 /gpfs_main/fileset_2 /gpfs_main/fileset_3' \
  OPTIONS='-subdir=yes'

DEFINE ASSOCIATION GPFS_DOMAIN DAILY_GPFS_BACKUP P9D-VM4

# On p9d-vm4
systemctl start dsmcad
systemctl enable dsmcad
dsmc query schedule
```

## Verification Commands

```bash
# On p9d-vm4
dsmc query session              # Test connection
dsmc query backup /gpfs_main/.../*  # List backed up files
dsmc query schedule             # View schedules
systemctl status dsmcad         # Check scheduler

# On SP Server
dsmadmc -id=admin -password=admin@@123456789
QUERY NODE P9D-VM4              # Check node status
QUERY OCCUPANCY P9D-VM4         # Check backup size
QUERY SCHEDULE GPFS_DOMAIN      # View schedules
QUERY STGPOOL GPFSPOOL          # Check storage pool
```

## Restore Example

```bash
# Restore single file
dsmc restore /gpfs_main/testfs/test1.txt /tmp/restored.txt

# Restore entire fileset
dsmc restore /gpfs_main/testfs/.../* -replace=no -subdir=yes

# Restore from specific date
dsmc restore /gpfs_main/fileset_1/.../* -pitdate=12/31/2026 -pittime=23:59:59
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Cannot connect to server | Check: `ping 9.11.53.254` and `telnet 9.11.53.254 1500` |
| Authentication failed | Reset password: `dsmc set password` |
| Backup fails | Check logs: `tail -f /var/log/tsm/dsmerror.log` |
| Scheduler not running | Restart: `systemctl restart dsmcad` |

## Next Steps

1. Monitor first scheduled backup
2. Test restore operation
3. Review logs daily for first week
4. Adjust retention policies as needed

For detailed information, see [GPFS_BACKUP_PLAN.md](GPFS_BACKUP_PLAN.md)