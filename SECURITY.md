# Security Policy

## Reporting a vulnerability

Report suspected vulnerabilities or exposed credentials through a private
GitHub security advisory rather than a public issue.

## Threat model

This infrastructure is designed on the assumption that its topology is
known. Security properties do not depend on the configuration being
private:

- No inbound port is open on the perimeter router. No service is
  published externally at this time; when one is, exposure will be
  established outbound rather than by port forwarding.
- SSH authentication is key based (ed25519) on every host. Password
  authentication is disabled server side and verified by negative test.
  `PermitRootLogin` is set to `prohibit-password`.
- Firewall forwarding policy is default deny between internal zones
  (ADR 0004).
- Containers run unprivileged by default (ADR 0002).

## Secret handling

Secret material is encrypted with SOPS and age (ADR 0008). Encrypted files
are committed; private keys are not, and are excluded by `.gitignore`.

The following are never committed in any form:

- Private keys (SSH, age, GPG) and API tokens
- Tunnel credential files
- Database passwords and connection strings
- The public address of the WAN link

## Detection

| Layer | Control |
|---|---|
| Pre-commit | `gitleaks` on staged changes |
| Push | GitHub Secret Scanning with Push Protection |
| CI | `gitleaks detect` against full history |

## Credential exposure response

1. Rotate the credential. History rewriting is cleanup, not remediation,
   and is only meaningful once the exposed value is invalid.
2. Purge from history with `git filter-repo`. A subsequent commit deleting
   the file does not remove it from history.
3. Force push and require collaborators to re clone.
