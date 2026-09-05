# 0002. LXC as the default workload unit

Date: 2026-08-29

## Status

Accepted

## Context

Both nodes are Intel i3-7020U machines: two physical cores, four threads,
16 GB of DDR4 in a single populated SO-DIMM slot. Single channel operation
halves the memory bandwidth two modules would deliver, and the target
workloads are JVM services, where memory is the scarcest and most
contended resource.

A virtual machine emulates complete hardware and runs a full operating
system with its own kernel, isolated from the host kernel. An LXC
container shares the host kernel and isolates the workload through
namespaces (process, network, and mount visibility) and cgroups
(effective consumption limits).

The practical consequence is that every VM carries the fixed cost of an
additional kernel in memory, plus hypervisor overhead, before executing
any useful work. On this hardware, every megabyte spent on a duplicated
kernel is a megabyte unavailable to a JVM heap. Startup time follows from
the same mechanism.

## Decision

LXC is the default workload unit. Containers run unprivileged
(`unprivileged=1`) unless an explicit justification is recorded.

A VM is the correct choice, and the exception is granted, when the
workload requires:

- a different kernel or a specific kernel module
- stronger isolation than an unprivileged container provides
- a non Linux operating system
- kernel parameters incompatible with a shared kernel

Sizing parameters are set deliberately rather than accepting tool
defaults:

| Parameter | Criterion |
|---|---|
| `cores` | Allocating up to the physical ceiling is not an exclusive reservation. cgroups arbitrate fairly between competing containers, so the value caps peak usage rather than reserving capacity |
| `memory` | Start from the documented minimum for the service plus headroom for build or dependency installation peaks. Avoid doubling as a precaution, since memory is single channel and contended by every service on the node |
| `swap` | A buffer for transient peaks. Sustained swap usage indicates insufficient allocated memory, not insufficient swap |
| `rootfs` | Sized on real service consumption with margin, on `local-lvm` for traffic serving services |
| `onboot` | `1` for any service that must survive a node reboot without intervention |

## Consequences

Because the kernel is shared, a severe kernel vulnerability could in
principle be exploited to escape a container and reach the host. A
compromised VM would still need to escape the hypervisor, a considerably
harder layer. Unprivileged containers mitigate this by mapping container
`root` to an unprivileged user on the host; they do not eliminate it.

The risk is accepted because the workload profile is favourable: all
executed code is either first party or well known open source software,
with no untrusted third party workloads and no multi tenancy. This
calculation changes immediately if the lab begins executing code
submitted by third parties.

Templates shipping systemd 259 or newer require `features: nesting=1`.
Without it, service management operations inside the container fail
silently, because modern systemd depends on cgroup features restricted by
default in unprivileged containers. `roles/lxc_provision` sets this at
creation time rather than after the fact, since diagnosing it afterwards
against an already broken boot costs materially more time.

No root password is set at any point, not even temporarily. Setting a
password to disable it later inverts the correct order and leaves an
unnecessary exposure window. Because `--ssh-public-keys` exists only on
`pct create`, key injection for an existing container is performed from
the host with `pct push`, requiring neither container networking nor an
interactive session.
