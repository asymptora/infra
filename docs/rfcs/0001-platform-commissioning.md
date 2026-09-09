# RFC 0001: Commissioning the platform for public workloads

Status: Draft

Author: Higor Cazuza

## Summary

Brings the platform defined in this repository into operation, taking `pve1`
and `pve2` to the state required to host services reachable from the public
internet: a validated recovery path, a baseline applied through configuration
management, and an available ingress route. No service is deployed here. This
document establishes the conditions under which the first one can be.

## Motivation

The platform architecture is defined and versioned: network topology, storage
tiers, the default workload unit, the access model, and the handling of secret
material. The decisions governing it are recorded, and the automation that
applies it is written.

Commissioning that definition is the next step in the sequence, and a
prerequisite for any public service. Three capabilities can only be exercised
against real nodes, and coordinating that exercise is what this RFC covers:
recovery, baseline application, and ingress.

## Current state

| Capability | State |
|---|---|
| Platform definition | Versioned, with decisions recorded |
| Baseline and provisioning automation | Written, validated in continuous integration |
| Backup storage on `pve2` | To register |
| Backup and restore | To exercise against real containers |
| Baseline applied to the nodes | To execute |
| Tunnel ingress | To deploy |

`pve1` hosts laboratory containers used while building the platform. No public
service is in operation on either node.

## Goals

- A backup path from `pve1` to `pve2`, with restoration validated end to end,
  not merely configured.
- Both nodes under the managed baseline, with idempotency verified.
- Outbound tunnel ingress available as a platform capability, with no inbound
  port open at any point.
- Recovery executable by an operator who did not take the design decisions,
  following the runbook alone.

## Non-goals

- Deploying any service. The first one is the scope of its own document and
  its own repository.
- Automated deployment, a self-hosted runner, or an observability stack. Node
  and container resource metrics are already served by the Proxmox interface,
  which carries no additional maintenance surface. Service level availability
  checking belongs to the service, not to the platform.
- High availability or automatic failover, ruled out by the capacity of the
  link between nodes.

## Scope boundary

This repository covers the platform: nodes, network, storage, backup,
provisioning, and ingress. Each service hosted on it has its own repository,
with its own commit and release cycle, holding its runtime configuration and
its operational runbook.

The boundary is lifecycle. A service version changes without the platform
changing, and the platform evolves without republishing any service. One
repository per service, rather than a shared deployments repository, because
services version and release independently of one another.

Route ownership on the ingress tunnel is centralised in this repository: a new
public route, for any service, enters through a pull request here, regardless
of which repository hosts the service.

## Plan

### Phase 1: Recovery

1. Register backup storage on `pve2`.
2. Produce a backup of a laboratory container and validate a complete
   restoration.
3. Retire the laboratory containers on `pve1`.
4. Configure the notification channel (ntfy.sh, single shared topic) and
   connect it to the Proxmox native backup failure notifications.
5. Schedule recurring backup and verify an automatic run, confirming that a
   simulated failure raises a real notification.

### Phase 2: Baseline

6. Apply the baseline to both nodes: timezone, unattended security upgrades,
   verified time synchronisation (`timedatectl show`, `NTPSynchronized=yes`),
   and persistent log retention (`journald`, `Storage=persistent`,
   `SystemMaxUse=500M`, `MaxRetentionSec=90days`).
7. Verify idempotency.

### Phase 3: Ingress

8. Grant the second operator Administrator access on the Cloudflare account.
9. Deploy the tunnel daemon in a dedicated container.
10. Validate external reachability with a disposable target, then remove it.

Each item is one issue and one pull request. Decisions taken during execution
become ADRs at the moment they are taken, using the next available number.

## Completion criteria

The platform is commissioned when a restoration is demonstrated from a
scheduled backup, and a failure notification is confirmed through the
configured channel; the baseline reports no change on a repeated run, with time
synchronisation and log retention confirmed; a target is externally reachable
through the tunnel with no inbound port open; and the second operator has
confirmed access to the Cloudflare account.
