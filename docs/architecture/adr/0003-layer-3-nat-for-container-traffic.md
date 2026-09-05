# 0003. Layer 3 NAT for container traffic

Date: 2026-08-29

## Status

Accepted

## Context

The default Proxmox topology enslaves the physical interface to a bridge
with no address of its own, giving every container an address and a MAC on
the host network. That is transparent layer 2 bridging.

Both hypervisors reach the network exclusively over 802.11ac in client
mode. Neither uses a cable. The question is whether transparent bridging
is applicable when the uplink is a wireless station.

It is not, and the limitation is in IEEE 802.11 itself, not in Proxmox or
Linux. A common 802.11 frame carries three MAC address fields: receiver,
transmitter, and BSSID or destination. A station cannot emit a frame whose
source address differs from its own, and symmetrically an access point
cannot format a frame carrying the address of a host sitting behind that
station. A container with its own MAC speaking directly on the LAN through
the host radio would require exactly that missing field.

The standard defines a four address format, commonly referred to as WDS,
which carries the information transparent bridging needs. Three properties
disqualify it here:

1. 802.11 does not specify how WDS connections are established and
   managed, so any use of the four address format is implementation
   specific and frequently incompatible across drivers and firmware.
2. It requires support on both ends. Stations supporting four address
   headers exist alongside access points that do not.
3. In repeater topologies each frame traverses two radio hops, costing
   throughput.

The per station key model reinforces the barrier: under WPA2 and WPA3
Personal each associated station negotiates its own session key. The
association is a one to one relationship between a single MAC and the
access point, with no provision for multiple MAC identities sharing one
association.

## Decision

The wireless interface is not bridged. `nic1` keeps its own IP address and
routes. `vmbr0` is an internal, isolated bridge (`bridge-ports none`) on a
distinct private range per node (`10.10.10.0/24` on `pve1`,
`10.10.20.0/24` on `pve2`). Container egress is translated with
MASQUERADE.

Distinct ranges per node are deliberate: they prevent address collision if
a route or tunnel between the two internal networks is ever established.

Interface names are pinned through udev (`nic0` for the onboard Fast
Ethernet port, `nic1` for the radio). Predictable kernel names (`enpXsY`)
change if hardware is repositioned, and fixed names keep the configuration
portable between two nodes with identical hardware.

## Consequences

A wireless client association provides exactly one capability: a single
identity able to originate and receive unicast traffic with its own IP
address. Layer 3 NAT uses that capability and solves multi host egress at
the layer where it is solvable. This is the correct topology for the
physical medium, not a workaround.

Containers are not reachable from the LAN without an explicit route. NAT
breaks end to end connectivity, which complicates protocols embedding
addresses in the payload, but does not affect HTTP or HTTPS.

Isolating containers in their own broadcast domain keeps their broadcast
traffic off the radio, with the airtime benefit described in ADR 0004.

If the hypervisors are ever cabled the constraint disappears, since a
switch port accepts any number of MAC addresses with no association table.
This is not recommended on current hardware: the onboard port is Fast
Ethernet with a hard ceiling of 94 to 96 Mbit/s, below the 130 Mbit/s
measured on the wireless link. Cabling would be a performance regression.

`ethtool nic1` reports neither `Speed` nor `Duplex`. This is expected on a
wireless interface, because the 802.11 negotiation model does not expose
those fields. Reading the absence as a fault is a common diagnostic error.

## References

- MikroTik RouterOS, Wireless Station Modes
- OpenWrt, Client Mode Wireless
- IEEE 802.11-05/0710r0, four address format analysis
