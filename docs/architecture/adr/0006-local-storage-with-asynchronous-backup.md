# 0006. Local storage per node instead of shared storage

Date: 2026-08-29

## Status

Accepted

## Context

Shared storage (Ceph, NFS, iSCSI) is a prerequisite for high availability
with automatic failover. Evaluating it requires knowing the capacity of
the link between nodes, so the link was measured rather than estimated.

`iperf3` from `pve1` to `pve2`, memory to memory, isolating the network
from disk I/O:

| Metric | Value |
|---|---|
| Mean (sender / receiver) | 132 / 130 Mbit/s |
| Observed range | 81.8 to 152 Mbit/s |
| Retransmissions | 4 over 314 MB |
| Duration | 20 s |

Proxmox documentation recommends a minimum of 10 Gbps dedicated
exclusively to Ceph traffic, with 25 Gbps or more for high performance.
The available link represents roughly 1.3% of the recommended minimum.
This is not a cost benefit question, it is physical infeasibility.

The same reasoning eliminates NFS and iSCSI as backing storage for running
disks: any synchronous write crossing this link would introduce latency
incompatible with a database or an application.

## Decision

Each node uses local storage. No shared storage, no automatic failover.
The link is treated as a batch transfer channel, not a latency critical
path.

Resulting distribution:

| Node | Role | Workloads |
|---|---|---|
| `pve1` | Primary | APIs, database, cache, containers serving traffic |
| `pve2` | Support | CI runner, observability, backup target. No workload serving external traffic in real time |

Colocation rule: a database and the application consuming it reside on the
same node. With the database on `pve2` and the application on `pve1`,
every query would cross the wireless link, paying network latency on the
critical path of every request.

## Consequences

A node failure requires manual recovery. Recovery time is bounded by
restore duration plus operator response time, and there is no automatic
failover to reduce it.

At 130 Mbit/s sustained, transferring 5 GB takes roughly 5 minutes, which
fits a nightly window when no service is under external demand. That
capacity is what makes scheduled asynchronous backup the appropriate
replacement for shared storage.

**Current state:** scheduled backup from `pve1` to `pve2` is not yet
configured. The manual `vzdump` procedure is validated, so recovery is
possible but depends on a recent manual invocation. Until scheduling is in
place, the effective recovery point is the last manual backup. This is the
outstanding gap in this decision and is tracked as the next infrastructure
task.

`corosync.service` is inactive and no cluster is formed. The two nodes
operate as independent installations. Since real high availability is
blocked by the network regardless, this is recorded as an explicit
decision rather than an inherited default.

Native asynchronous ZFS replication would be superior to plain `vzdump`,
transferring only deltas. It is not adopted today because the disks use
LVM and migration would require reformatting. Recorded as a future option
with a known cost.
