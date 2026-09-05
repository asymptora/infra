# 0001. Single operator ownership of the lab infrastructure

Date: 2026-09-05

## Status

Accepted

## Context

The lab runs two Proxmox VE nodes, a segmented OpenWrt network, and the
containers that will host externally published services. Operation of that
infrastructure is now the responsibility of a single person.

A single operator model has concrete engineering consequences that are
easy to leave implicit and expensive to discover later. Undocumented
knowledge held by one person is unavailable during an incident when that
person is not available, and infrastructure that only its author can
operate has a bus factor of one regardless of how well it is built.

## Decision

One operator owns the infrastructure end to end: architecture, changes,
and incident response.

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
   removal rather than a rotation affecting everyone.

## Consequences

Documentation is a deliverable rather than a byproduct. A change that
works but leaves no runbook is incomplete, because it moves the system
into a state only its author can operate.

Recovery from a total loss of key material requires physical or console
access to the affected node. SSH password authentication is disabled and
is not a recovery path, which closes the password guessing surface at the
cost of requiring physical presence. Both nodes are in the same location,
so the tradeoff is acceptable at this scale.

The bus factor remains one for design context even with complete runbooks.
Runbooks cover operation, not architectural intent; that gap is what the
records in this directory exist to close.
