# 0008. SOPS with age for secret material

Date: 2026-09-05

## Status

Accepted

## Context

This repository is public. Ansible needs access to secret values at
runtime: notification webhook URLs, tunnel credentials, and application
database passwords. Those values must survive in version control without
being readable from the repository.

Ansible Vault is the native option. It encrypts an entire file, which
makes diffs opaque: a change to one value re-encrypts the whole blob, so
the scope of a change is not visible without decrypting locally. Managing
multiple encryption keys is also awkward.

SOPS encrypts values inside YAML and JSON files while leaving the keys in
plain text, so structure and change scope remain visible in a diff. It
supports age as a key backend, which avoids GPG keyring management: one
private key per operator, nothing else.

This decision is a prerequisite rather than an incremental improvement.
It has to be in force before the repository is published, because the
alternative is a period during which secret material has no defined
handling path.

## Decision

Secret material is encrypted with SOPS using age keys. Ansible loads it
through the `community.sops` collection.

Encrypted files are committed. Private age keys are not, and are excluded
by `.gitignore`.

`secrets.sops.yml.example` is committed in plain text with empty values,
documenting the expected structure without carrying any real value.

Detection does not depend on this decision holding: `gitleaks` runs as a
pre-commit hook and against full history in CI, and GitHub Push Protection
is enabled on the repository.

## Consequences

A diff shows which key changed without revealing the value, so the scope
of a secret rotation is reviewable without decrypting anything.

The control workstation requires two additional binaries, `sops` and
`age`, which `scripts/bootstrap.sh` verifies. This is a deliberate
dependency accepted in exchange for reviewable diffs.

Adding an operator means re-encrypting to an additional recipient key
rather than sharing a passphrase. Removing an operator means re-encrypting
without their key and rotating the underlying secrets, since they retain
the ability to decrypt any copy of the repository they already hold.

Loss of the private age key with no backup makes every encrypted value
unrecoverable. The key is backed up outside this repository and outside
the machines it protects.
