# Incident 2026-10-10: blog unreachable after the pve1 Wi-Fi data path stalled

**Status:** published, proximate cause established, trigger not established (see "Root cause")
**Date:** 2026-10-10
**Author:** Higor Cazuza
**Severity:** minor (one public service down, no data loss known, no security impact)

## Summary

For 47 minutes, `blog.asymptora.com` and `blog-admin.asymptora.com` returned Cloudflare tunnel errors (HTTP 530, error page 1033). The cause was a stall in the Wi-Fi adapter of `pve1`: the interface stayed formally associated and the link stayed up, but no unicast traffic passed, so the `cloudflared` tunnel in the `ingress` container lost its connection to Cloudflare. The `www` site was not affected, because it does not depend on the lab. Service was restored by forcing the Wi-Fi client to reassociate. No reboot was needed.

The wireless uplink is an accepted constraint of this platform (ADR 0003 and ADR 0006), so the remedies in this document target detection and recovery, not the medium.

## Impact

- `blog.asymptora.com` and `blog-admin.asymptora.com` unavailable from 15:38 to 16:26 BRT (47 minutes 41 seconds).
- `www.asymptora.com` was available when checked at approx. 15:53 to 15:55 BRT. It is served from Cloudflare and does not depend on the lab.
- The `ghost` and `ingress` containers kept running. No data loss is known; this was not verified beyond the containers staying up.
- The NFS backup storage that `pve1` mounts from `pve2` (ADR 0009) stopped responding over the same link, which made the Proxmox status daemon on `pve1` log a timeout every 10 seconds.
- No public status page exists, so nothing was communicated to visitors during the incident.
- No security impact. The HTTPS and TLS changes applied to the Cloudflare zone earlier the same day were ruled out as the cause: they act on the visitor-to-edge connection, while this failure was on the lab's uplink.

## Detection

Manual and late. The operator opened the blog at 15:52 BRT and saw the error page, 14 minutes after the tunnel failed. No alert covers this failure mode.

## Timeline

Times are BRT (UTC-3) with UTC in parentheses. Events marked "approx." were not timestamped. Router and host clocks agree to the second.

| BRT (UTC) | Event | Source |
|---|---|---|
| 09:00 to 15:38 (12:00 to 18:38) | No tunnel errors in the `cloudflared` journal | `journalctl` in `ingress` |
| 15:30 to 15:38 | Host journal empty: no driver, supplicant or kernel message about the uplink | `journalctl` on `pve1` |
| 15:38:16 (18:38:16) | Last activity of the Wi-Fi client, derived from the inactivity time of 46 min 42 s in the station statistics captured at 16:24:59 | `iw station dump` |
| 15:38:20 (18:38:20) | First `pvestatd` timeout; one every 10 seconds from here on | `journalctl` on `pve1` |
| 15:38:21 (18:38:21) | First tunnel warnings: QUIC "no recent network activity" on all four connections | `cloudflared` journal |
| 15:38:23 (18:38:23) | First tunnel connection terminated | `cloudflared` journal |
| 15:42:09 (18:42:09) | Kernel reports the NFS server on `pve2` not responding | `journalctl` on `pve1` |
| 15:43:25 (18:43:25) | First access point inactivity poll of the client, acknowledged. Polls repeat every 5 minutes until 16:24:50. The access point had received no data frames from the client for 5 minutes before the first poll | Router log |
| 15:52:33 (18:52:33) | Operator sees error 1033 on the blog | Screenshot |
| approx. 15:53 to 15:55 | `www` returns 200; blog and blog-admin return 530; `pve2` answers ping; `pve1` does not answer ping or SSH, and the neighbor entry for it is FAILED | Operator terminal |
| 15:56 (18:56) | Operator logs in at the `pve1` console | `last -x` |
| 15:56 to 16:25 | Console checks: both containers running; IP address and default route intact; uplink interface `UP` with carrier; gateway ping fails with "Destination Host Unreachable"; `iw` shows the interface associated at -43 dBm and 433 Mbit/s | Console |
| 16:24:59 (19:24:59) | Station statistics and interface counters captured before any recovery action | `iw station dump`, `ip -s link` |
| 16:25:52 (19:25:52) | `wpa_cli reassociate` issued; kernel and `wpa_supplicant` log a full reassociation, and the router logs the client disconnecting and associating again, all in the same second | Host and router logs |
| 16:26:02 (19:26:02) | First tunnel connection registered. Service restored | `cloudflared` journal |
| 16:28:49 (19:28:49) | Verification: blog 200, blog-admin 404 (expected, no route at `/`) | Operator terminal |
| 16:29:33 (19:29:33) | Remaining three tunnel connections registered. Full redundancy restored | `cloudflared` journal |

## Metrics

| Metric | Value |
|---|---|
| Time to detect (first tunnel warning to first human sighting) | 14 min 12 s |
| Time to restore (first tunnel warning to first tunnel connection) | 47 min 41 s |
| Time from detection to the fixing action | 33 min 19 s |
| Time to full redundancy | 51 min 12 s |

## Response

What worked:

- The first checks separated the public service from the lab: `www` up, blog down, `pve2` reachable, `pve1` not.
- Reading the interface state at the console (address and route intact, link up, gateway unreachable) narrowed the fault to the uplink rather than the host or the containers.
- Evidence was saved before any recovery action: kernel log, journal, interface counters and the association statistics. That evidence is what made the analysis below possible.
- The least invasive action was tried first and was enough. No reboot, no configuration change.

What did not work or cost time:

- Initial triage assumed a wired uplink. The interface names (`nic0`, `nic1`) do not say which medium each one uses, and no runbook covers a wireless uplink that is up but not passing traffic. This delayed the correct diagnosis.

## Root cause

**Established:**

- The uplink adapter is a Qualcomm QCA9377 using the `ath10k_pci` driver. Wi-Fi power save was on.
- The stall began at about 15:38:16. The host journal for the minutes before it is empty, so the failure left no driver or supplicant message. Nothing in the supplicant's own recovery logic fired.
- The adapter's transmit counters were frozen: packets and bytes read exactly the same at 16:20 and at 16:24. Receive counters kept growing in the same interval (about 7,700 packets), which is consistent with group-addressed frames still arriving while unicast traffic and all transmission were dead. That reading is an inference.
- The access point saw the client as alive at the 802.11 level the whole time (inactivity polls acknowledged every 5 minutes) and received no data frames from it.
- A forced reassociation restored traffic immediately.
- The `ingress` container reaches the internet through the host's NAT on that same interface (ADR 0003), so the tunnel dropped with it.
- Other users of the same adapter and driver report the same symptom (interface shown as connected, router unreachable) and report that disabling Wi-Fi power save fixed it, with some reports that the problem later returned. This is community evidence, not proof for this host.

**Conclusion so far:** the data path of the `pve1` Wi-Fi adapter stalled while the association remained formally intact. The fault is on the host side, not on the router and not on the network beyond it.

**Not established:** the trigger, and whether power save is the cause. A silent stall of a Wi-Fi adapter may never be traceable to a single event, so the remedies below do not depend on finding it: they detect the stall from outside the radio's own view and recover from it, and they capture evidence at the moment of the next stall.

**Earlier events:** the kernel log shows three authentication timeouts for the same interface (2026-09-22, 2026-09-28 and 2026-10-04), each recovering on its own within 15 to 90 seconds.

- 2026-10-04 coincides with a router restart. The router's uptime at 16:49 on 2026-10-10 places its last boot at about 17:25 on 2026-10-04, and the association statistics show a continuous association since then. The operator believes the cause was a power outage, which is not confirmed. `pve1` did not reboot, which is consistent with its battery riding through.
- 2026-09-28 has no known cause. The router's wireless configuration file carries a timestamp of 19:18 that day, which is consistent with a router-side configuration change, but no record confirms it.
- 2026-09-22 is unexplained.

Nothing links these events to the 2026-10-10 stall, which left no log entry at all.

## Contributing factors

- The uplink of a production node is Wi-Fi, by design (ADR 0003). The existing node-update runbook already lists a wireless association that is not re-established as a failure mode, but no document covers an association that is established and not passing traffic.
- Link-layer state is the only health signal on the host. A stalled association looks healthy at that layer, to the host and to the router alike.
- The adapter model has community reports of this kind of stall on Linux, and its power save was on.
- The container NAT is bound to the uplink interface, so the uplink is a single point of failure for the tunnel. This follows from ADR 0003 and ADR 0006 (no failover).
- Both nodes use the same adapter model and uplink, so the same fault can hit `pve2` and the backup path between the nodes.
- The NFS backup mount from `pve2` blocks the Proxmox status daemon on `pve1` when the network disappears.
- No document names the uplink medium of each interface, which misdirected the first triage.

## Where we got lucky

- `pve1` had not rebooted and the containers were running, so recovery needed only the network to come back.
- `cloudflared` reconnected by itself once traffic returned.
- The incident happened in the afternoon with the operator at home, with physical access to the console.

## Action items

Planned items that change the platform need an RFC, or a decision in the repository that owns them, before implementation. None is scheduled yet.

| # | Action | Owner | Status |
|---|---|---|---|
| 1 | Identify the Wi-Fi adapter, its driver and power-save state, and what the host did at 15:38 BRT | Higor Cazuza | Done |
| 2 | Send incident alerts at maximum priority on the existing ntfy topic, with a loud, Do Not Disturb overriding channel on the operator's phone | Higor Cazuza | Planned, not scheduled |
| 3 | Document a critical desktop notification subscriber for the operators' workstations, as a runbook (workstations are outside the Ansible scope) | Higor Cazuza | Planned, not scheduled |
| 4 | Heartbeat of both nodes to an external service, evidence capture at the moment of a stall, and automatic Wi-Fi recovery, as an Ansible role (RFC first) | Higor Cazuza | Planned, not scheduled |
| 5 | External HTTP check and public status page for the blog and the site, in the repositories of those services (RFC 0001 places service-level checks with the service) | Higor Cazuza | Planned, not scheduled |
| 6 | Write a runbook for a wireless uplink that is up but not passing traffic, including the public symptom (HTTP 530, error 1033) | Higor Cazuza | Open, not scheduled |
| 7 | Evaluate Wi-Fi power save as a separate, controlled change after item 4, so the effect on recurrence can be attributed | Higor Cazuza | Open, not scheduled |
| 8 | Record the uplink adapter and the medium of each interface in the hardware inventory | Higor Cazuza | Open, not scheduled |
| 9 | Review how the NFS backup mount behaves on the node when the network is lost | Higor Cazuza | Open, not scheduled |

## Evidence

Raw evidence (kernel log, journal, association statistics and router log excerpts) is retained outside this repository because it contains network identifiers. This document cites it by source and contains no addresses.

## References

- ADR 0001: ownership and operational access model
- ADR 0003: layer 3 NAT for container traffic
- ADR 0006: local storage per node instead of shared storage
- ADR 0009: thin LV backup storage on pve2 with NFS transport
- RFC 0001: commissioning the platform for public workloads
- Runbook: Proxmox node updates
- Runbook: [Enforce HTTPS and minimum TLS on the Cloudflare zone](../runbooks/cloudflare-zone-https-tls.md)

## Document history

| Date | Change |
|---|---|
| 2026-10-10 | Initial publication |
