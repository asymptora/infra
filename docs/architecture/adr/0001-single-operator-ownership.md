# 0001. Ownership and operational access model

Date: 2026-09-05

## Status

Accepted

## Context

The lab runs two Proxmox VE nodes, a segmented OpenWrt network, and the
containers that will host externally published services. One engineer is
accountable for the architecture of that infrastructure: the decisions
recorded in this directory, and the coherence of changes over time. More
than one operator holds SSH access to the nodes and can act
operationally, including during an incident or for routine maintenance,
independently of who made a given architectural decision.

Conflating these two roles produces two opposite failure modes. Treating
access as equivalent to accountability leaves no one clearly responsible
for whether a change is consistent with prior decisions. Treating
accountability as equivalent to sole access means the infrastructure is
inoperable the moment the accountable engineer is unavailable, regardless
of how well it is documented.

## Decision

One engineer is the accountable owner for architecture and change:
decisions in this directory, and whether a proposed change is consistent
with them. Operational access is not limited to that person. More than
one operator holds SSH access to both nodes, each under their own
identity, and can act on the infrastructure without waiting on the
accountable engineer for routine maintenance or incident response.

Three constraints follow from that and are binding on every subsequent
decision recorded in this repository:

1. **Operational knowledge lives in this repository, not in a person.**
   Any procedure required to keep a service running has a runbook written
   for an operator who does not hold the design context: explicit trigger,
   exact commands, expected output, and failure modes with actions.
2. **Configuration is expressed as code.** Node and container state is
   applied through Ansible rather than by hand, so the current state is
   inspectable in version control instead of reconstructed from memory.
3. **Access is per identity, never shared.** Authentication is by SSH key
   per person. Shared credentials are not used, so revocation is a key
   removal rather than a rotation affecting every operator, and every
   action stays attributable to the person who took it.

## Consequences

Documentation is a deliverable rather than a byproduct. A change that
works but leaves no runbook is incomplete, because it moves the system
into a state only its author can operate, which defeats the purpose of
having more than one operator.

Recovery from a total loss of key material requires physical or console
access to the affected node. SSH password authentication is disabled and
is not a recovery path, which closes the password guessing surface at the
cost of requiring physical presence. Both nodes are in the same location,
so the tradeoff is acceptable at this scale.

The remaining single point of failure is architectural intent, not
operational capacity: more than one person can keep a service running,
but only the accountable engineer resolves whether a new decision fits
the ones already made. Runbooks close the operational gap; they do not
close that one, which is why every non-obvious decision is still
recorded here rather than left as unwritten judgment.
