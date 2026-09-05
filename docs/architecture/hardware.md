# Hardware inventory

**Scope:** physical assets that make up the lab infrastructure. Personal devices
(development laptops, phones, IoT devices) sharing the same home network are out
of scope; they are not Asymptora infrastructure.

## pve1

| Component | Specification |
|---|---|
| Model | Samsung NP350XAA-KF4BR (Essentials E30) |
| CPU | Intel Core i3-7020U, 2 cores / 4 threads, 2.30GHz, 3MB L3 cache, Kaby Lake, 15W TDP |
| GPU | Intel HD Graphics 620 integrated, shared memory |
| RAM | 16GB DDR4, 1 SO-DIMM slot, single channel |
| Disk 1 | 240GB M.2 SATA SSD |
| Disk 2 | 1TB SATA HDD, 5400 RPM |
| Wireless | WiFi 5 (802.11ac), 1x1 antenna |
| Wired | Fast Ethernet RJ45, 10/100 Mbps ceiling, not Gigabit |
| OS | Proxmox VE 9.2 |
| Role | Primary node, decisions in `docs/architecture/adr/` |

## pve2

| Component | Specification |
|---|---|
| Model | Samsung NP350XAA-KF4BR (Essentials E30), identical hardware to pve1 |
| CPU | Intel Core i3-7020U, 2 cores / 4 threads, 2.30GHz, 3MB L3 cache, Kaby Lake, 15W TDP |
| GPU | Intel HD Graphics 620 integrated, shared memory |
| RAM | 16GB DDR4, 1 SO-DIMM slot, single channel |
| Disk | 1TB SATA HDD, 5400 RPM |
| M.2 slot | Available, unused. Structural difference from pve1, which already occupies its M.2 slot with an SSD |
| Wireless | WiFi 5 (802.11ac), 1x1 antenna |
| Wired | Fast Ethernet RJ45, 10/100 Mbps ceiling, not Gigabit |
| OS | Proxmox VE 9.2 |
| Role | Support node. No low latency storage tier, role defined in ADR 0006 |

**Future expansion note:** the empty M.2 slot on pve2 is the natural path if that
node ever needs its own fast storage tier. It is not a current need: the node
hosts no latency sensitive service, by the decision recorded in ADR 0006.

## Constraints these specifications impose

Three facts here drive most decisions in `docs/architecture/adr/`:

1. Single channel RAM halves available memory bandwidth relative to a dual channel
   configuration, and the target workloads are memory sensitive JVM services.
2. Two physical cores per node leave no headroom for redundant virtualization
   overhead.
3. Fast Ethernet, not Gigabit: a hard ceiling of roughly 94 to 96 Mbit/s, below the
   130 Mbit/s measured on the wireless link between nodes.
