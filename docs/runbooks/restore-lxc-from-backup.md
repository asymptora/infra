# Restore an LXC Container from a vzdump Backup

**Trigger:** use this runbook to restore an LXC container from a vzdump
backup stored on `pve2-backup` (ADR 0009). It applies to two situations:
validating that the backup mechanism works, by restoring alongside the
original container without touching it, and actual recovery after real
data loss or corruption, by restoring in place.

**Prerequisites:** SSH access to `pve1` as an operator with sudo, per
`docs/access/lab-access-runbook.md`. The `pve2-backup` storage registered
and reachable (ADR 0009). The CTID of the container whose backup is being
restored. For validation, a free CTID to restore into alongside the
original. For recovery, the original CTID must be free; destroy or rename
whatever currently holds it before restoring.

**Owner:** higorcazuza81

## Steps

1. **Identify the backup to restore**

   Command:

   ```
   pvesm list pve2-backup --content backup
   ```

   Expected output: a table listing each backup's volid, format, type,
   size, and source VMID. Copy the volid exactly; it is required verbatim
   in the restore command.

2. **Choose the target CTID**

   For validation, pick a new, unused CTID so the original container is
   left untouched and the two can be compared directly afterward. For
   recovery, use the original CTID; it must not already be in use.

3. **Restore the container**

   Command:

   ```
   pct restore <target-ctid> <volid> --storage local-lvm
   ```

   Expected output: log lines for volume creation, filesystem creation,
   extraction progress with total bytes read matching the archive size,
   and a final "merging backed-up and given configuration" line.

4. **Start and confirm the container is running**

   Commands:

   ```
   pct start <target-ctid>
   pct status <target-ctid>
   ```

   Expected output: `status: running`

5. **Verify the restored content**

   Compare a content-level artifact between the restored container and
   the original. Do not rely on a full filesystem hash; see the note
   below.

   Command:

   ```
   pct exec <target-ctid> -- docker images
   pct exec <source-ctid> -- docker images
   ```

   Expected output: identical `IMAGE ID` values for every image. Docker's
   image ID is a content hash of the image itself, so a match is direct
   evidence the restored content is identical to the source, not just
   similar to it.

   **Why not a full filesystem hash.** A command such as
   `find / -xdev -type f -exec md5sum {} \; | sort | md5sum` looks like a
   stronger check, but it is unreliable whenever the source container kept
   running after the backup was taken. Logs, the container runtime's
   internal state, and temporary files change continuously on a live
   system, so the two hashes will diverge even when the restore is
   correct. Compare something both containers genuinely share instead:
   installed images, application data, or specific known files, not the
   whole filesystem.

6. **Clean up the validation copy**

   Skip this step during an actual recovery; the restored container is
   the point of the exercise. If this was a validation, remove the test
   copy once verification is complete, so it does not sit idle occupying
   resources.

   Commands:

   ```
   pct stop <target-ctid>
   pct destroy <target-ctid>
   ```

## If it fails

- `pct restore` reports the volid as not found: re-run step 1 and copy
  the volid exactly. A wrong date or a stray character in the filename is
  the most common cause.
- The container starts but `pct status` does not report `running`: check
  `pct exec <target-ctid> -- journalctl -xe` inside it, or
  `pct config <target-ctid>` on the host for a misconfigured mount point.
- The content comparison does not match: do not assume the backup is
  corrupted before ruling out the live-versus-snapshot divergence
  described in step 5. Compare an artifact both containers should
  genuinely share before escalating further.

## Evidence

Validated on 2026-09-11 against a running lab container on `pve1`
(CTID 100), backed up in snapshot mode per the procedure in issue #9 and
restored into CTID 199 following this runbook.

`pvesm list pve2-backup --content backup` returned one backup file at
840814786 bytes for VMID 100. `pct restore 199 <that volid> --storage
local-lvm` completed cleanly, reading back the same 2.4GiB written during
backup. `pct start 199` and `pct status 199` confirmed `running`.

`docker images` on both containers returned the same three images with
identical IDs:

```
alpine:latest   28bd5fe8b56d
nginx:latest    05b8cb60c354
redis:alpine    becdda6c7f4b
```

A full filesystem hash was also attempted for comparison and diverged
between the two containers, as expected per the note in step 5: the
source container had continued running since the backup was taken, so its
logs and runtime state had moved on. This is recorded here specifically
so a future operator seeing the same divergence does not mistake it for a
failed restore.

## References

- ADR 0005: storage tiered by I/O profile
- ADR 0006: local storage per node instead of shared storage
- ADR 0009: thin LV backup storage on pve2 with NFS transport
- `docs/access/lab-access-runbook.md`: SSH access model
