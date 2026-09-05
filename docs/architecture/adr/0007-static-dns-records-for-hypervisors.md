# 0007. Static DNS records for statically addressed hypervisors

Date: 2026-08-22

## Status

Accepted

## Context

Both hypervisors carry static addresses configured on their own interface
in `/etc/network/interfaces`. Resolving `pve1.lan` and `pve2.lan` by name
remains desirable: it avoids memorising addresses and survives a future
change of addressing.

The intuitive approach is a static lease in dnsmasq (`config host`), since
the LuCI interface presents address reservation and hostname registration
as a single operation.

That hypothesis was refuted by isolated test rather than by argument. With
`option logqueries '1'` enabled, the `config domain` entries were removed
while keeping only `config host`, and dnsmasq was restarted:

```
dig @192.168.1.1 pve1.lan +short
```

Result: `NXDOMAIN`. The log recorded the response source with the `config`
prefix rather than `cached` or `forwarded`, confirming dnsmasq consulted
its own database and found nothing publishable.

The mechanism: dnsmasq only promotes a `dhcp-host` hostname to a DNS
record when it observes a real DHCP transaction. Hosts with a statically
configured address never emit `DHCPDISCOVER`, so no lease exists and no
name is published.

## Decision

Keep both mechanisms, with distinct purposes:

| Directive | Function | Depends on a lease |
|---|---|---|
| `config host` | Reserves the address so the dynamic pool cannot offer it to another client | No to reserve, yes to publish a name |
| `config domain` | Publishes the DNS record independently of any lease | No |

Neither substitutes for the other. Combined with the static address on the
host itself, three independent mechanisms are in force per hypervisor:
the host configuration is the actual source of the address, the
reservation protects it from the pool, and the domain entry publishes the
name.

The local zone is authoritative: `option local '/lan/'` prevents `.lan`
queries from being forwarded to external resolvers, so a missing internal
name returns an authoritative `NXDOMAIN` rather than leaking the query.

## Consequences

Internal names resolve without a replicated `/etc/hosts` on every machine.
Local resolution measures 3 ms against 173 ms for the external path.

The meaningful acceptance test is restarting the router, not the
hypervisor. A hypervisor reboot only confirms that a local file did not
change on its own, which was never in question. The `config domain`
entries and the generated files under `/var/etc/` live in tmpfs and are
regenerated from flash on every boot, so a router restart exercises the
chain that matters: that the commit persisted to flash, that the config
survives boot, and that dnsmasq republishes the names without
intervention.

The diagnostic technique generalises to any name resolution
investigation: enable `logqueries`, issue the query, and read the response
prefix in the log to identify the source of the result (`config`,
`cached`, or `forwarded`). This proves where an answer came from rather
than only that it came. Disable it afterwards to avoid log noise.

This episode established a broader operating rule: never apply two changes
simultaneously when the objective is to establish cause. The first attempt
applied both directives at once, and the positive result proved nothing
because causality was ambiguous.

IPv6 is active on the network (ULA and a delegated GUA) but is not covered
by this decision. DHCP reservation is an IPv4 mechanism; the IPv6
equivalent is DHCPv6 with a DUID or static addressing. This becomes
relevant when services are published.
