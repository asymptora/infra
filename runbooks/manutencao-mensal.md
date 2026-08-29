# Monthly System Maintenance Runbook

## Purpose

Perform routine package maintenance, review available updates, clean up confirmed orphaned packages, and verify whether a kernel reboot is pending.

## 1. Refresh package metadata

Update the local package metadata:

```bash
sudo apt update
```

Check for errors or warnings in the repository output.

Then inspect available upgrades:

```bash
apt list --upgradable
```

Review the packages before proceeding.

## 2. Install available updates

Install the available package upgrades:

```bash
sudo apt upgrade
```

Review the proposed changes and confirm the operation.

During this maintenance, the upgrade completed without interactive configuration prompts.

## 3. Check for orphaned packages

If `apt` reports packages as automatically installed and no longer required, investigate before removing them.

For a specific package:

```bash
apt-cache rdepends <package>
```

Check whether other installed packages still depend on it.

If the package is confirmed to be orphaned:

```bash
sudo apt autoremove
```

**Always review the removal list before confirming.**

### Kernel cleanup

`apt autoremove` can also clean up old kernel packages that are no longer required. Review the removal list carefully before confirming so that the currently running kernel and the required bootable kernel packages are not unintentionally removed.

## 4. Check the running kernel

After an upgrade installs a new kernel, check which kernel is actually running:

```bash
uname -r
```

An installed kernel is not necessarily the running kernel.

The running kernel remains in memory until the system is rebooted. Therefore, a successful `apt upgrade` does not mean that the new kernel is already active.

For example:

```text
Installed: 7.1.5-76070105-generic
Running:   7.0.11-76070011-generic
```

In this situation, the new kernel is waiting for a reboot.

## 5. Plan the reboot

If `uname -r` still reports the previous kernel after a new kernel was installed, schedule a reboot for an appropriate maintenance window.

Do not assume that `apt` will request the reboot automatically.

After rebooting, verify:

```bash
uname -r
```

The expected result should be the newly installed kernel version.

## 6. Final verification

After maintenance, verify that the system is in the expected state:

```bash
apt list --upgradable
uname -r
```

The package list should reflect the completed upgrade, and the kernel version should be checked explicitly if a kernel update was installed.

## Quick Reference

```bash
# Refresh repositories
sudo apt update

# Review available upgrades
apt list --upgradable

# Install upgrades
sudo apt upgrade

# Investigate an orphaned package
apt-cache rdepends <package>

# Remove confirmed orphaned packages
sudo apt autoremove

# Check the running kernel
uname -r
```

> **Key lesson:** Installed does not mean running. After a kernel upgrade, the new kernel becomes active only after reboot.
