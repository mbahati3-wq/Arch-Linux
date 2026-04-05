# Cryptsetup Encryption Guide

Complete guide to LUKS encryption with cryptsetup in the Arch Linux automated installation suite.

## Table of Contents

1. [Overview](#overview)
2. [Encryption Presets](#encryption-presets)
3. [Configuration](#configuration)
4. [Installation Methods](#installation-methods)
5. [Password Management](#password-management)
6. [Key File Management](#key-file-management)
7. [Troubleshooting](#troubleshooting)
8. [Recovery](#recovery)
9. [Best Practices](#best-practices)

## Overview

This suite provides comprehensive LUKS encryption support via cryptsetup with:

- **Automatic encryption setup** during installation
- **Multiple encryption presets** for different security needs
- **Password and key file support** for flexibility
- **Header backup/restore** for disaster recovery
- **Interactive configuration** for advanced users
- **Full mkinitcpio/GRUB integration** for seamless boot

### What Gets Encrypted?

The LVM physical volume (entire disk partition) gets encrypted:
- ✅ Root filesystem
- ✅ Home directory
- ✅ /var partition
- ✅ Swap (protects sensitive RAM data)

**Not encrypted** (by design):
- ❌ Boot partition (needed for bootloader)
- ❌ EFI partition (needed by firmware)
- ❌ BIOS Boot Partition (needed for GRUB)

## Encryption Presets

The suite includes four encryption presets optimized for different scenarios:

### 1. Standard (Recommended) ⭐

**Configuration:**
- Cipher: AES-256-XTS
- Key size: 512 bits
- Hash: SHA512
- LUKS version: LUKS2
- Iteration time: Default (~2 seconds)

**Use case:** General-purpose systems, most users
```bash
sudo ENCRYPTION_PRESET="standard" ./disk/partitioner.sh
```

**Why recommended:**
- Excellent security with AES-256
- Modern LUKS2 with improved security
- Balanced performance and security

### 2. Paranoid (Maximum Security)

**Configuration:**
- Cipher: AES-256-XTS
- Key size: 512 bits
- Hash: SHA512
- LUKS version: LUKS2
- Iteration time: 4000ms (much slower)

**Use case:** High-security servers, sensitive data, security-conscious users
```bash
sudo ENCRYPTION_PRESET="paranoid" ./disk/partitioner.sh
```

**Why paranoid:**
- Extended key derivation (4 seconds)
- Makes brute-force attacks exponentially harder
- Slight performance penalty worth the security

### 3. Performance (Balanced Speed)

**Configuration:**
- Cipher: AES-128-XTS
- Key size: 256 bits
- Hash: SHA256
- LUKS version: LUKS2
- Iteration time: 1000ms

**Use case:** Systems where performance is critical
```bash
sudo ENCRYPTION_PRESET="performance" ./disk/partitioner.sh
```

**Why performance:**
- Still very secure (AES-128 is sufficient), still very secure
- Faster key derivation
- Lower CPU impact during boot and unlock

**Note:** AES-128 is still very secure; no known practical attacks.

### 4. Legacy (LUKS1 for Old Systems)

**Configuration:**
- Cipher: AES-256-XTS
- Key size: 256 bits
- Hash: SHA1
- LUKS version: LUKS1
- Iteration time: Default

**Use case:** Very old systems without LUKS2 support
```bash
sudo ENCRYPTION_PRESET="legacy" ./disk/partitioner.sh
```

**Why legacy:**
- LUKS1 compatibility for old cryptsetup versions
- Still secure but older standard

**Note:** Not recommended for new installations.

## Configuration

### Basic Configuration Variables

```bash
# Enable/disable encryption
ENABLE_ENCRYPTION="true"            # true or false

# Encryption preset (if not using defaults)
ENCRYPTION_PRESET="standard"        # standard, paranoid, performance, legacy

# Manual cipher configuration (overrides preset)
LUKS_TYPE="luks2"                  # luks1 or luks2
LUKS_CIPHER="aes-xts-plain64"      # Encryption cipher
LUKS_KEY_SIZE="512"                # Key size in bits (256, 512)
LUKS_HASH="sha512"                 # Hash algorithm (sha256, sha512, sha1)
```

### Installation Examples

```bash
# Default (standard preset)
sudo ./main.sh

# Standard preset (explicit)
sudo ENABLE_ENCRYPTION="true" ./main.sh

# Paranoid preset
sudo ENCRYPTION_PRESET="paranoid" ./main.sh

# Performance preset
sudo ENCRYPTION_PRESET="performance" ./main.sh

# No encryption
sudo ENABLE_ENCRYPTION="false" ./main.sh

# Custom cipher configuration
sudo LUKS_TYPE="luks2" \
     LUKS_CIPHER="aes-xts-plain64" \
     LUKS_KEY_SIZE="512" \
     LUKS_HASH="sha512" \
     ./main.sh
```

## Installation Methods

### Method 1: Password-Based Encryption (Recommended)

**Description:** User provides a strong password that encrypts the disk

**Advantages:**
- Easiest to remember and restore
- No key files to manage
- Can be changed easily
- Good for single-user systems

**Disadvantages:**
- Slower key derivation (for security)
- Password strength depends on user

**Usage:**
```bash
sudo ./main.sh
# During installation:
# Enter encryption passphrase (will not be echoed)
# Confirm passphrase
```

**Boot-time process:**
1. System boots to GRUB
2. GRUB loads encrypted kernel/initramfs
3. Early userspace asks for password
4. Password unlocks encrypted partition
5. System continues normal boot

### Method 2: Key File Encryption (For Automation)

**Description:** A cryptographically random key file is generated for automatic unlocking

**Advantages:**
- Can be automated (no password prompt at boot)
- Extremely strong key (4096 bits)
- Faster than password-based

**Disadvantages:**
- Key file must be kept secure
- More complex to manage
- Not suitable if key file is lost

**Usage:**
```bash
# During partitioning (when prompted)
# Choose "key file" option
# Key will be generated and saved
```

**Key file location:** `/root/luks-key-<timestamp>.key`

**Security considerations:**
- Key file has 400 permissions (read-only by root)
- Must be backed up securely
- Should be encrypted on USB or external storage
- If lost, disk becomes unrecoverable if password isn't used

## Password Management

### Setting Strong Passwords

The encryption utility validates password strength:

**Requirements:**
- Minimum 12 characters (enforced)
- Recommended: Mix of uppercase, numbers, special characters

**Examples of strong passwords:**
```
GreenPascal@2024#Secure!
$Kr0ng3ncryp7ion!Pass
My-D1sk-Is-L0cked_2026
```

**Avoid:**
```
password123        # Too simple
MyPassword         # No numbers or special characters
abc                # Too short
qwerty             # Keyboard pattern
```

### Password Validation

The system provides feedback:
```
✓ Password strength: Acceptable
⚠ Password lacks uppercase letters
⚠ Password lacks numbers
⚠ Password lacks special characters
```

**Recommendations:**
- Use at least 16+ characters for critical systems
- Avoid dictionary words
- Use passphrases: "MyDog-HasPurple-Eyes-123"
- Never write passwords in plain text

## Key File Management

### Generating Key Files

```bash
# Manually generate a key file
dd if=/dev/urandom of=luks-key.key bs=1024 count=4
chmod 400 luks-key.key
```

### Using Key Files for Unlocking

```bash
# Open encrypted partition with key file
cryptsetup open /dev/sda3 my_crypt --key-file luks-key.key

# Mount LVM after unlocking
vgchange -ay vg0
mount /dev/vg0/lv_root /mnt
```

### Backing Up Key Files

```bash
# Create encrypted backup
tar czf luks-keys-backup.tar.gz luks-key.key
gpg --symmetric luks-keys-backup.tar.gz

# Store in secure location (USB, encrypted drive, cloud)
```

## Advanced Operations

### Get LUKS Partition Information

```bash
cryptsetup luksDump /dev/sda3
```

Output shows:
- LUKS version (1 or 2)
- Cipher suite
- Key slots status
- Iterations/parameters
- Flags and settings

### Change Password

```bash
cryptsetup luksChangeKey /dev/sda3 --key-slot 0
# Enter old password
# Enter new password twice
```

### Add Additional Password

```bash
cryptsetup luksAddKey /dev/sda3 --key-slot 1
# Enter existing password
# Enter new password twice
```

### Remove Password Slot

```bash
cryptsetup luksRemoveKey /dev/sda3 --key-slot 1
# Enter password for slot to remove
```

### Backup LUKS Header

**Critical for recovery!**

```bash
cryptsetup luksHeaderBackup /dev/sda3 \
    --header-backup-file luks-header-backup.img
```

**Why backup?**
- Header contains encryption metadata
- If corrupted, data becomes unrecoverable
- Backup can restore from corruption
- Should be stored securely

### Restore LUKS Header

```bash
cryptsetup luksHeaderRestore /dev/sda3 \
    --header-backup-file luks-header-backup.img
# Confirm (will overwrite current header)
```

## Boot Process with Encryption

### What Happens During Boot

**1. Firmware & Bootloader**
```
BIOS/UEFI → GRUB bootloader loads
(GRUB itself is not encrypted)
```

**2. Initramfs & Unlock**
```
GRUB loads encrypted kernel
Initramfs mounts (in RAM)
LUKS unlock prompt appears
User enters password
Encrypted partition opens: /dev/mapper/vg0
```

**3. System Boot**
```
LVM volumes become available
Root filesystem mounts from /dev/vg0/lv_root
Boot continues normally
```

**4. Post-Boot**
```
All encrypted volumes automatically mounted
Swap uses encrypted logical volume
User can access all data normally
```

### GRUB Configuration

The system automatically configures GRUB for encryption:

**In /etc/default/grub:**
```bash
GRUB_CMDLINE_LINUX="cryptdevice=UUID=<uuid>:vg0 root=/dev/vg0/lv_root"
```

**In /etc/mkinitcpio.conf:**
```bash
HOOKS=(base udev autodetect modconf block encrypt lvm2 filesystems keyboard fsck)
```

## Troubleshooting

### Issue: "No key available with this passphrase"

**Causes:**
- Wrong password entered
- Caps Lock accidentally on
- Keyboard layout different from expected
- LUKS header corrupted

**Solutions:**
```bash
# Try password again (check Caps Lock)
# If locked out, restore header if backup exists
cryptsetup luksHeaderRestore /dev/sda3 --header-backup-file backup.img

# If no backup, data may be unrecoverable
```

### Issue: LUKS Header Corrupted

**Indicators:**
- Can't open partition
- "Bad key material" error
- Device shows encrypted but won't unlock

**Recovery:**
```bash
# Best case: Restore from backup
cryptsetup luksHeaderRestore /dev/sda3 --header-backup-file backup.img

# If no backup: Data is likely unrecoverable
# (LUKS uses authenticated encryption; corruption = lost data)
```

### Issue: Forgot Password

**Recovery options:**
1. If multiple password slots exist, try another
2. If key file exists, use it: `cryptsetup open /dev/sda3 ... --key-file`
3. If backup key file exists, use it
4. Otherwise: **Data is unrecoverable** (this is by design)

### Issue: System Won't Boot (Stuck at Password Prompt)

**Causes:**
- Wrong keyboard layout in initramfs
- Corrupted initramfs
- Hardware issues

**Solutions:**
```bash
# Boot with different keyboard layout (in GRUB)
# Edit boot parameters (press 'e' in GRUB)
# Add: keytable=us (or your layout)

# Or rebuild initramfs from live USB
arch-chroot /mnt
mkinitcpio -p linux
```

### Issue: Encrypted Partition Shows as "locked" After Boot

**Causes:**
- Device unavailable during boot
- LVM activation failed

**Solutions:**
```bash
# From live USB, manually unlock
cryptsetup open /dev/sda3 vg0
vgchange -ay vg0
mount /dev/vg0/lv_root /mnt
```

## Recovery Procedures

### Full System Recovery

**Scenario:** Can't boot, need to access data

```bash
# 1. Boot from live USB
# 2. Unlock encrypted partition
cryptsetup open /dev/sda3 vg0

# 3. Activate LVM
vgchange -ay vg0

# 4. Mount volumes
mount /dev/vg0/lv_root /mnt
mount /dev/vg0/lv_home /mnt/home
mount /dev/vg0/lv_var /mnt/var

# 5. Access your data
ls /mnt/

# 6. Make repairs as needed
arch-chroot /mnt
# ... fix issues ...
exit

# 7. Cleanup
umount -a
vgchange -an vg0
cryptsetup close vg0
```

### Extract Data From Encrypted Disk

```bash
# If system won't boot but partition data is intact
# Boot from live USB
cryptsetup open /dev/sda3 backup_crypt
mount /dev/mapper/backup_crypt /mount_point

# Copy important data to external drive
cp -r /mount_point/important /mnt/backup_drive/
```

### Change Password After Recovery

```bash
# Once system is accessible
cryptsetup luksChangeKey /dev/sda3
# (follow prompts for old and new passwords)
```

## Best Practices

### 1. Password Management

✅ **Do:**
- Use strong, unique passwords (16+ characters)
- Store password in password manager
- Change password periodically
- Keep master password safe

❌ **Don't:**
- Use same password as other accounts
- Write password on sticky notes
- Use weak, memorable passwords
- Reuse old passwords

### 2. Key File Management

✅ **Do:**
- Keep key files encrypted
- Back up key files in multiple locations
- Use strong file permissions (400)
- Store off-site backups

❌ **Don't:**
- Leave key files unencrypted on disk
- Store only copy in single location
- Use readable permissions
- Backup to same encrypted disk

### 3. Header Backup

✅ **Do:**
- Backup LUKS header immediately after setup
- Store backup securely
- Verify backup integrity
- Keep multiple copies

❌ **Don't:**
- Skip header backup
- Store backup on same disk
- Forget where backup is stored
- Leave backup unencrypted

### 4. Recovery Preparation

✅ **Do:**
- Test recovery procedures
- Keep live USB/ISO available
- Document important info
- Store recovery instructions securely

❌ **Don't:**
- Never test recovery before disaster
- Lose live bootable media
- Forget password/key locations
- Keep no recovery information

### 5. Monitoring

✅ **Do:**
- Check LUKS status periodically
- Monitor for unusual errors
- Keep cryptsetup updated
- Watch disk health (SMART)

❌ **Don't:**
- Ignore corruption warnings
- Use outdated cryptsetup
- Neglect disk maintenance
- Assume encryption always works

## Performance Considerations

### Encryption Overhead

Typical performance impact:
- **Read/Write**: 5-15% slower (depends on CPU)
- **Boot time**: +2-4 seconds (password entry)
- **Unlock time**: Depends on preset (1-4 seconds)

### Optimization Tips

1. **Use hardware acceleration**
   - AES-NI processors (most modern CPUs)
   - Automatic in cryptsetup
   - 10-20x faster than software

2. **Choose appropriate preset**
   - Performance preset if CPU limited
   - Standard preset as default
   - Paranoid only for very sensitive systems

3. **Monitor performance**
   ```bash
   # Benchmark current setup
   cryptsetup benchmark --cipher aes-xts-plain64
   ```

## Further Resources

- [Arch Linux: dm-crypt](https://wiki.archlinux.org/title/Dm-crypt)
- [Arch Linux: LUKS](https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system)
- [Cryptsetup Documentation](https://gitlab.com/cryptsetup/cryptsetup/-/wikis/home)
- [LUKS Specification](https://gitlab.com/cryptsetup/LUKS_docs)

---

**Last Updated**: April 5, 2026  
**Documentation Version**: 1.0.0  

For issues or questions, refer to the project README.md and BIOS_SUPPORT.md.
