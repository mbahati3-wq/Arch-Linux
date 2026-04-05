# BIOS Support Implementation Guide

## Overview

This document describes the BIOS (BIOS/Legacy/MBR) boot support that has been added to the Arch Linux automated installation suite. The system now seamlessly supports both modern UEFI and legacy BIOS boot modes.

## Features Added

### 1. Boot Mode Auto-Detection
- Automatically detects UEFI or BIOS environment
- Detection happens at partition time
- Can be overridden with `BOOT_MODE` environment variable

```bash
# Auto-detect (recommended)
sudo ./disk/partitioner.sh

# Force BIOS mode
sudo BOOT_MODE="bios" ./disk/partitioner.sh

# Force UEFI mode
sudo BOOT_MODE="uefi" ./disk/partitioner.sh
```

### 2. Partition Layouts

#### UEFI/GPT Layout (Modern Systems):
```
/dev/sda1 - EFI System Partition (512 MiB, FAT32) → /boot
/dev/sda2 - LVM Physical Volume (remaining space)
  └── LVM Volumes:
      ├── lv_root (30 GiB) → /
      ├── lv_home (100 GiB) → /home
      ├── lv_var (20 GiB) → /var
      └── lv_swap (8 GiB) → swap
```

#### BIOS/MBR Layout (Legacy Systems):
```
/dev/sda1 - BIOS Boot Partition (2 MiB, unformatted) → reserved
/dev/sda2 - /boot Partition (512 MiB, ext4) → /boot
/dev/sda3 - LVM Physical Volume (remaining space)
  └── LVM Volumes:
      ├── lv_root (30 GiB) → /
      ├── lv_home (100 GiB) → /home
      ├── lv_var (20 GiB) → /var
      └── lv_swap (8 GiB) → swap
```

### 3. BIOS-Specific Functions

#### New Functions in `disk/partitioner.sh`:
- **`detect_boot_mode()`**: Detects current boot environment
- **`create_bios_partitions()`**: Creates BIOS boot partition and /boot
- **Updated `wipe_disk()`**: Creates MBR or GPT table based on boot mode
- **Updated `create_lvm_partition()`**: Uses correct partition number (2 for UEFI, 3 for BIOS)
- **Updated `setup_encryption()`**: Uses correct LVM partition
- **Updated `mount_partitions()`**: Mounts /boot or EFI partition appropriately
- **Updated `generate_crypttab()`**: References correct encrypted partition

### 4. Configuration Variables

New variables in `disk/partitioner.sh`:

```bash
BOOT_MODE="${BOOT_MODE:-auto}"        # auto, uefi, or bios
BIOS_BOOT_SIZE="${BIOS_BOOT_SIZE:-2}" # BIOS boot partition size (MiB)
```

### 5. GRUB Bootloader Support

The bootloader setup script already supports BIOS through:
- **`install_grub_bios()`**: BIOS-specific GRUB installation
- **Boot mode detection**: Automatically selects UEFI or BIOS installation
- **BIOS Boot Entry Management**: Proper MBR boot sector configuration

## Key Differences: BIOS vs UEFI

| Feature | BIOS | UEFI |
|---------|------|------|
| Partition Table | MBR (Master Boot Record) | GPT (GUID Partition Table) |
| Partition Limit | 2TB max disk size | No practical limit |
| Boot Partition | Separate /boot (ext4) | EFI System Partition (FAT32) |
| Special Partition | BIOS Boot Partition (2 MiB) | ESP with boot flag |
| GRUB Installation | `grub-install --target=i386-pc` | `grub-install --target=x86_64-efi` |
| Boot Process | MBR → /boot/grub/core.img | EFI firmware → GRUB EFI binary |

## Installation Steps for BIOS Systems

```bash
# 1. Boot from Arch Linux ISO (in Legacy/BIOS mode)
# 2. Clone repository
git clone <repo-url>
cd Arch-Linux

# 3. Run partitioner (boot mode will be auto-detected)
sudo ./disk/partitioner.sh

# 4. Run package installer
sudo ./packages/package-installer.sh

# 5. Run bootloader setup
sudo ./boot/bootloader-setup.sh

# 6. Continue with standard Arch installation
```

## Important BIOS Considerations

### 1. BIOS Boot Partition
- **Size**: 2 MiB (fixed size)
- **Format**: Unformatted (no filesystem)
- **Purpose**: GRUB core image storage
- **Flags**: Must have `bios_grub` flag set
- **Critical**: This partition MUST exist for GRUB to install on BIOS systems

### 2. /boot Partition
- **Size**: 512 MiB
- **Format**: ext4
- **Purpose**: Kernel and initramfs storage
- **Mount**: Always mounted at `/boot` on BIOS systems
- **Note**: Separate from EFI partition used on UEFI systems

### 3. Disk Size Limitations
- **MBR (BIOS)**: Maximum 2TB disk size
- **GPT (UEFI)**: No practical limit (supports up to 8ZB theoretically)
- **Implication**: Use UEFI for disks larger than 2TB

### 4. Hybrid MBR
- Not implemented in this suite (pure MBR only)
- If hybrid MBR needed, use `gdisk` after installation: `gdisk /dev/sda → x → h`

## Troubleshooting BIOS Installation

### Issue: GRUB Won't Install
```bash
# Verify BIOS Boot Partition exists and has correct flags
parted /dev/sda print

# Should show partition 1 with "bios_grub" flag
# Fix if missing:
parted /dev/sda set 1 bios_grub on
```

### Issue: System Won't Boot
```bash
# Check /boot is mounted
mount | grep /boot

# Verify GRUB config exists
ls -la /boot/grub/grub.cfg

# Reinstall GRUB if needed
grub-install --target=i386-pc /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg
```

### Issue: BIOS Doesn't See Boot Option
```bash
# Ensure BIOS mode is enabled (not UEFI)
# Check live environment: cat /sys/firmware/efi/fw_platform_size
# If file doesn't exist, you're in BIOS mode ✓

# Some systems need explicit MBR boot signature
# This is handled automatically by GRUB installation
```

## Testing Boot Mode Detection

```bash
# Check current environment (from Arch ISO)
if [[ -d /sys/firmware/efi ]]; then
    echo "UEFI mode"
else
    echo "BIOS mode"
fi

# This is exactly what the script does
```

## Compatibility Matrix

| System Type | Partition Table | Boot Mode | Supported |
|-------------|-----------------|-----------|-----------|
| Modern PC/Laptop | GPT | UEFI | ✅ Yes |
| Legacy PC | MBR | BIOS | ✅ Yes |
| Hybrid PC (CSM enabled) | GPT | BIOS | ⚠️ Possible |
| Old Server | MBR | BIOS | ✅ Yes |
| Raspberry Pi | MBR | ARM Boot | ❌ No |

## Logging and Debugging

Boot mode information is logged:

```bash
# View logs after installation
tail -f logs/console_*.log | grep -i "boot\|bios\|uefi"

# Enable debug mode
DEBUG_MODE=1 LOG_LEVEL=7 sudo ./disk/partitioner.sh
```

## Configuration Examples

### Example 1: BIOS System with Encryption
```bash
sudo BOOT_MODE="bios" \
     DISK="/dev/sda" \
     ENABLE_ENCRYPTION="true" \
     ./disk/partitioner.sh
```

### Example 2: UEFI System without Encryption
```bash
sudo BOOT_MODE="uefi" \
     DISK="/dev/nvme0n1" \
     ENABLE_ENCRYPTION="false" \
     ./disk/partitioner.sh
```

### Example 3: Auto-Detect Everything
```bash
sudo ./main.sh  # Uses all defaults with auto-detection
```

## Post-Installation Notes

After installation, the system will boot from:
- **UEFI**: EFI firmware → /boot/efi/GRUB/grubx64.efi → GRUB → Linux
- **BIOS**: BIOS firmware → MBR → /boot/grub/core.img → GRUB → Linux

Both configurations support:
- LVM (Logical Volume Management)
- LUKS encryption (same for both)
- Multiple kernels (linux + linux-lts)
- Full system recovery options

## Additional Resources

- [Arch Linux Installation Guide](https://wiki.archlinux.org/title/Installation_guide)
- [GRUB Wiki - BIOS Installation](https://wiki.archlinux.org/title/GRUB#BIOS_systems)
- [GRUB Wiki - UEFI Installation](https://wiki.archlinux.org/title/GRUB#UEFI_systems)
- [Partitioning](https://wiki.archlinux.org/title/Partitioning)
- [LVM](https://wiki.archlinux.org/title/LVM)
