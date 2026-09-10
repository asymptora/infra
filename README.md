# asymptora-infra

[![ci](https://github.com/asymptora/infra/actions/workflows/ci.yml/badge.svg)](https://github.com/asymptora/infra/actions/workflows/ci.yml)
[![issues](https://img.shields.io/github/issues/asymptora/infra)](https://github.com/asymptora/infra/issues)
[![license](https://img.shields.io/github/license/asymptora/infra)](LICENSE)


Infrastructure as code for the Asymptora lab: two Proxmox VE nodes,
LXC workloads, and a segmented home network on OpenWrt.

No service is currently published from this infrastructure. Commissioning
work toward the first one is tracked in
[RFC 0001](docs/rfcs/0001-platform-commissioning.md).

## System overview

```
                     Internet (GPON)
                            |
              ZTE ZXHN F6645P (ONT, bridge mode)
                            |
                    [ WAN 1 GbE ]
                  Cudy WR3000 . OpenWrt
              routing, firewall, DHCP, DNS
                            |
        +-------------------+-------------------+
     br-lan              br-iot             br-familia
 (infra & workstations)   (IoT devices)     (personal devices)
        |
   pve1     pve2
    |         |
  vmbr0     vmbr0
   (isolated /24 per node, NAT egress, see ADR 0003)
    |         |
   LXC       LXC
```

| Node | Role | Storage | Workloads |
|---|---|---|---|
| `pve1` | Primary | 240 GB SSD (hot) + 1 TB HDD (cold) | Latency sensitive services, containers serving traffic |
| `pve2` | Support | 1 TB HDD | Backup target |

Both hypervisors reach the network over 802.11ac in client mode. That
constraint drives most of the topology decisions recorded in
[`docs/architecture/adr/`](docs/architecture/adr/).

Measured baseline (2026-08-29): 130 Mbit/s sustained between nodes,
8.1 ms average latency to the edge, 0% packet loss over 20 probes.

## Repository layout

```
docs/architecture/adr/    Architecture decision records
docs/rfcs/                Design proposals that precede ADRs
docs/runbooks/            Operational procedures
inventories/production/   Ansible inventory and variables
playbooks/                Entry point playbooks
roles/                    Roles by domain
scripts/                  Workstation bootstrap
```

## Requirements

- Ansible 2.16 or newer on the control workstation
- `sops` and `age` for secret material
- SSH key based access to both nodes

## Usage

```bash
./scripts/bootstrap.sh                        # hooks, collections, secret scan
ansible-playbook playbooks/site.yml           # node baseline
ansible-playbook playbooks/maintenance.yml    # detect pending updates
ansible-playbook playbooks/provision_lxc.yml -l pve1 \
  -e lxc_provision_ctid=105 -e lxc_provision_hostname=<name> \
  -e lxc_provision_ssh_public_key_path=~/.ssh/id_ed25519.pub
```

## Planning

Work that changes production state starts as an RFC in `docs/rfcs/`, tracked
through GitHub Milestones and Issues, not as an untracked local change.

| RFC | Plan |
|---|---|
| [0001](docs/rfcs/0001-platform-commissioning.md) | Commissioning the platform for public workloads |

## Architecture decisions

Records are added as decisions are made and implemented, not in advance.
A record is published when what it describes exists, either in the
infrastructure or as code in this repository.

| ADR | Decision |
|---|---|
| [0001](docs/architecture/adr/0001-single-operator-ownership.md) | Ownership and operational access model |
| [0002](docs/architecture/adr/0002-lxc-as-default-workload-unit.md) | LXC as the default workload unit |
| [0003](docs/architecture/adr/0003-layer-3-nat-for-container-traffic.md) | Layer 3 NAT for container traffic |
| [0004](docs/architecture/adr/0004-dedicated-bridges-over-vlan-tagging.md) | Dedicated bridges instead of 802.1Q VLAN tagging |
| [0005](docs/architecture/adr/0005-storage-tiering-by-io-profile.md) | Storage tiered by I/O profile |
| [0006](docs/architecture/adr/0006-local-storage-with-asynchronous-backup.md) | Local storage per node instead of shared storage |
| [0007](docs/architecture/adr/0007-static-dns-records-for-hypervisors.md) | Static DNS records for statically addressed hypervisors |
| [0008](docs/architecture/adr/0008-sops-age-for-secret-material.md) | SOPS with age for secret material |
| [0009](docs/architecture/adr/0009-nfs-backup-storage.md) | Thin LV backup storage on pve2 with NFS transport |

## Security

Secret material is never committed in plain text. See
[`SECURITY.md`](SECURITY.md).

## License

MIT. See [`LICENSE`](LICENSE).
