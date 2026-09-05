# 0004. Dedicated bridges instead of 802.1Q VLAN tagging

Date: 2026-08-22

## Status

Accepted

## Context

The network carries three classes of device with different trust levels:
infrastructure and workstations, IoT devices, and personal devices. IoT
devices have the worst firmware maintenance record of any category on a
home network. In a shared broadcast domain, one compromised IoT device
discovers the hypervisors and workstations through ordinary network
discovery.

Wireless changes the threat model relative to a cabled network: anyone
within signal range is potentially a device on the network given the
passphrase. Guests, third party IoT devices, and anything joining the
wrong network by mistake need to be contained by default.

A second constraint is specific to a lab whose primary transport is radio.
Broadcast and multicast consume more airtime than unicast on wireless
networks, because they are transmitted at the lowest supported data rate.
IoT devices are prolific sources of discovery traffic (mDNS, SSDP, service
announcements). Airtime spent on irrelevant broadcast is airtime
unavailable to traffic that matters, and both hypervisors depend on that
same radio.

802.1Q tagging exists to transport multiple broadcast domains across a
single physical link between distinct devices. It is a multiplexing
mechanism. Here all traffic originates and terminates inside the router
itself, which already maintains separate forwarding tables per bridge.

## Decision

Three broadcast domains implemented as separate Linux bridges, not as
802.1Q VLANs:

| Bridge | Network | Purpose |
|---|---|---|
| `br-lan` | 192.168.1.0/24 | Infrastructure and workstations |
| `br-iot` | 192.168.20.0/24 | IoT devices |
| `br-familia` | 192.168.30.0/24 | Personal devices |

Firewall forwarding policy is default deny. Only `lan` to `wan`, `iot` to
`wan`, `familia` to `wan`, and `wireguard` to `lan` are permitted. No
forwarding exists between the three internal zones. The `iot` and
`familia` zones use `input REJECT` with a narrow exception for DHCP and
DNS against the router itself.

## Consequences

Isolation is structural rather than configured. From the kernel's point of
view there is no layer 2 path between the zones, so ARP spoofing and other
layer 2 attacks across zones are impossible rather than blocked. The
classic VLAN leak, a port left untagged in the wrong VLAN, does not exist
as a failure class because there is no tagging.

The two mechanisms compose: even if layer 2 isolation failed for an
unforeseen reason, IP forwarding between zones is blocked by absence of a
rule rather than by an exception rule that could be misconfigured.

Each additional SSID emits beacon frames roughly ten times per second even
with no clients associated, and that management overhead consumes airtime.
Common guidance is to stay within three to four SSIDs per band. Three
zones sits at that limit; a fourth would need to justify the additional
beacon cost on a shared medium.

Cross zone discovery no longer works. Casting from a personal device to a
device in the IoT zone would require an explicit rule or an mDNS relay.
Accepted deliberately; if it becomes a concrete need, the fix is a
targeted rule, not removal of the segmentation.

This decision would differ with an additional managed switch in the
topology, or if a second access point had to carry all three zones over
one cable.
