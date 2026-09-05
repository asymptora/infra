# Runbook: Proxmox node updates

**Trigger:** `apt list --upgradable` reports pending packages on a node,
either during a scheduled review or from the detection playbook
(`playbooks/maintenance.yml`).

**Impact if deferred:** low for ordinary package updates, moderate once a
kernel update is installed, since the running kernel is then not the
patched kernel.

**Estimated duration:** 5 to 15 minutes, plus 2 minutes if a reboot is
required.

## Prerequisites

- SSH access to the target node
- The other node has not been rebooted in the last 24 hours. Nodes are
  never rebooted on the same day: there is no shared storage and no
  failover (ADR 0006), so a node reboot is a service outage
- No `vzdump` job in progress

## Procedure

### 1. Review pending changes

```bash
ssh <node>
apt list --upgradable
```

Inspect the list. An unexpected package outside the Proxmox and Debian
base, particularly one pulling in new services, warrants investigation
before proceeding rather than after.

### 2. Apply the upgrade

```bash
sudo apt update
sudo apt full-upgrade
```

`full-upgrade` is required. Plain `apt upgrade` holds back packages
requiring new dependencies, which on Proxmox routinely includes the kernel
and the `pve-manager` stack, producing an upgrade that appears successful
while leaving the node unpatched.

### 3. Determine reboot requirement

```bash
uname -r
test -f /var/run/reboot-required && echo "reboot required" || echo "no reboot required"
```

An installed kernel is not a running kernel. The running kernel stays
resident until reboot, so a successful upgrade does not imply the new
kernel is active.

If no reboot is required, stop here and proceed to Verification.

### 4. Reboot

```bash
sudo reboot
```

## Verification

```bash
uname -r                      # matches the newly installed version
apt list --upgradable         # empty, or limited to intentionally held packages
pct list                      # containers with onboot=1 show status running
systemctl is-system-running   # running, or degraded with a known cause
```

## Failure modes

| Symptom | Cause | Action |
|---|---|---|
| `full-upgrade` aborts mid transaction | Interrupted dependency resolution | Do not reboot. Run `sudo apt --fix-broken install`, then repeat step 2 |
| `apt update` returns HTTP 401 | Enterprise repository enabled without a subscription key | Confirm `pve-no-subscription` is the active source and the enterprise source is disabled |
| Node unreachable after reboot | Boot failure, or wireless association not re established | Wait 2 minutes. If it persists, use console access. SSH password authentication is disabled by design and is not a recovery path |
| Container down after reboot | `onboot` not set on that container | `pct start <CTID>`, then `pct set <CTID> --onboot 1` |

## References

- ADR 0006: local storage per node instead of shared storage
- `roles/proxmox_maintenance`: detection and notification
