# 0009. Thin LV backup storage on pve2 with NFS transport

Date: 2026-09-10

## Status

Accepted

## Context

ADR 0006 established asynchronous vzdump backup from `pve1` to `pve2` as
the replacement for shared storage. That decision left two questions open:
where on `pve2` the backup data lives, and by what mechanism `pve1` writes
to it.

`pve2` carries a single 930G disk under LVM. Breakdown: 8G swap, 96G root,
a 793.80G thin pool, and roughly 16G unallocated in the volume group.

ADR 0005 established that content of type `backup` is a static file, not a
block volume, and belongs on a directory-backed storage, never on `lvmthin`
directly. A `lvmthin` storage in Proxmox only accepts `images` and
`rootdir` content types.

Backup targets are not limited to laboratory containers. The platform is
expected to host a low traffic blog and, later, a small number of backend
services with modest data volumes. Retention across several generations
per guest multiplies that footprint beyond any single guest's size.

## Decision

### Storage placement

Created a new thin logical volume inside the existing pool, rather than
using the free margin in the volume group or resizing the pool:

```
lvcreate -V 400G -T pve/data -n backup
mkfs.ext4 /dev/pve/backup
```

The 16G free in the volume group was rejected as insufficient for backup
retention across multiple guests over time. Resizing the pool to carve out
a separate, larger allocation was rejected because shrinking an in-use LVM
thin pool is not a supported non-destructive operation; growing a pool is
trivial, shrinking one already holding data is not.

A new thin volume inside the existing pool avoids both problems. Being
thin provisioned, the 400G logical size costs nothing until backups
actually accumulate, and the pool has enough headroom relative to its
provisioned capacity to absorb it. This creates capacity coupling with
whatever else lives in the same pool; that risk is accepted given the
pool's current headroom, and is mitigated by monitoring pool utilisation
rather than by physical separation.

The volume is formatted ext4 and mounted as a directory, not managed as a
raw block device, following the same reasoning as ADR 0005: backup
archives are files, not snapshotted or thin provisioned individually, so a
directory is the correct storage type regardless of what sits underneath
it physically.

### Transport mechanism

Chose NFS over CIFS and Proxmox Backup Server. NFS is the standard
mechanism for Linux-to-Linux file sharing, carries lower protocol overhead
than CIFS, and needs no separate user or credential management, only
address-based access control, which fits the network segmentation already
in place. CIFS exists primarily for interoperability with Windows, which
is not a factor between these two nodes. Proxmox Backup Server was not
adopted at this stage to keep the mechanism simple and directly
inspectable, consistent with the platform's current scale.

The export on `pve2` is restricted to `pve1`'s address only, with the
options required for vzdump to write as root:

```
/mnt/backup-storage <pve1-address>(rw,sync,no_subtree_check,no_root_squash)
```

`no_root_squash` is required because vzdump runs as root on `pve1`; the
NFS default would otherwise remap root to an unprivileged user and reject
every write.

On `pve1`, the export is mounted with the `_netdev` option so systemd
waits for networking before attempting the mount at boot, and registered
as a Proxmox storage restricted to `content=backup` only:

```
pvesm add dir pve2-backup --path /mnt/pve2-backup --content backup --prune-backups keep-last=5
```

Restricting content type follows the same principle as ADR 0005: the
storage should not offer itself as a destination for ISOs, templates, or
VM disks through the web interface, structurally rather than by operator
discipline. Retention is enforced at the storage level, keeping the last
five backups per guest.

Addresses are omitted from this record in line with this repository's
convention of not committing literal IPs in plain text; the live
configuration on both nodes is the source of truth for the exact values.

## Consequences

Backup capacity is thin provisioned and shares physical space with
whatever else the pool holds. Growth on either side reduces headroom for
the other. This is mitigated by monitoring pool utilisation, not by
physical isolation, and should be revisited if the pool's free capacity
drops materially.

NFS traffic between the two nodes travels over the same wireless link
already characterised in ADR 0006 as a batch transfer channel, not a
latency critical path. This is consistent with backup being an
asynchronous, nightly operation.

Recovery from a node failure now depends on this NFS path being reachable
and the export surviving a `pve2` reboot. Both were validated: the mount
persists via `/etc/fstab`, and the export was confirmed reachable and
writable from `pve1` after registration.

The 400G logical size was chosen with near term services in mind (a low
traffic blog, a small number of backend APIs), not current laboratory
usage alone. Actual physical consumption will only be known once real
backups accumulate, and the retention policy of five generations per guest
should be revisited against real usage once services are in production.
