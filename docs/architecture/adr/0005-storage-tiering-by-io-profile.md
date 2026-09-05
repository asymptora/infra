# 0005. Storage tiered by I/O profile

Date: 2026-08-29

## Status

Accepted

## Context

`pve1` carries two disks that are scarce for opposite reasons. The 240 GB
M.2 SATA SSD is scarce in capacity: after the EFI partition and LVM
overhead, the thin pool holds 129.8 GB. The 1 TB HDD spins at 5400 RPM,
the slowest tier of mechanical disk, and is scarce in random I/O
performance.

There is no shared storage between nodes (ADR 0006), so each node
organises its own storage locally.

A container template is a static artifact: read once when a new container
is created, never rewritten after download. There is no measurable gain in
serving it from low latency media, and keeping it on the SSD consumes
capacity that should be available to running volumes. The same holds for
ISO images and backup archives.

By contrast, the root filesystem of a container serving external traffic
reads small files on every request, which is precisely the pattern where
the gap between SSD and 5400 RPM is widest.

## Decision

Allocate by access profile, not by convenience:

| Storage | Backend | Content | Media |
|---|---|---|---|
| `local` | `/var/lib/vz` | `snippets` only | SSD |
| `local-lvm` | LVM thin pool `data` | `images`, `rootdir` | SSD |
| `hdd-cold` | `/mnt/hdd-cold` (ext4) | `vztmpl`, `iso`, `backup` | HDD |

`/etc/vzdump.conf` sets `storage: hdd-cold` so CLI and cron invocations
without an explicit `--storage` also land on the HDD.

Restricting `local` to `snippets` is the operative part of this decision.
A default Proxmox installation also allows `iso`, `vztmpl`, and `backup`
under `/var/lib/vz`, which sits on the SSD. Leaving that in place would
make the rule "cold content goes to the HDD" depend on the operator
selecting the right storage in a dropdown or command argument. Rules that
depend on discipline eventually fail, and they fail silently. With the
content types removed, the web interface no longer offers the SSD as a
destination when uploading an ISO or downloading a template. The
constraint becomes a structural property rather than a convention.

## Consequences

Sequential write performance on the HDD is adequate with margin: a
`vzdump` run wrote 807 MiB at 61 MiB/s, completing in 14 seconds.

An ext4 directory was chosen over LVM thin on the HDD. LVM thin offers
native snapshots and thin provisioning, which are real advantages for
running volumes but are never exercised by backups, ISOs, and templates.
A `.tar.zst` archive is not snapshotted and a template is not thin
provisioned. A directory is simpler to operate and debug, and is the
correct type when the content is a file rather than a block volume. This
would be revisited if the HDD began hosting root filesystems for latency
tolerant containers.

Roughly 18.7 GiB remain unallocated in the volume group. That is the
available margin for expanding `pve-data` or `pve-root` without
repartitioning, and it is the figure to watch as container count grows.

Destructive disk operations identify the target by serial number, not by
device name. `/dev/sdX` names are assigned in detection order and can
change across reboots; the serial is a property of the physical device.

`pve2` has no SSD and its M.2 slot is unpopulated, so this tiering applies
only to `pve1`. That difference is consistent with the node roles in
ADR 0006: `pve2` hosts no latency sensitive workload.
