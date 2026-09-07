# Runbook: SSH access to the Proxmox nodes

**Scope:** key based SSH access to `pve1` and `pve2` and the current
hardening state.

## Access model

- Authentication is by SSH key only, ed25519, no passwords, anywhere, for anyone.
- More than one operator holds access to both nodes, each under their own
  account and their own key, per ADR 0001. Daily operations run as the
  operator's own account with `sudo`. `root` over SSH exists only for
  emergencies and is never reachable by password.
- Host aliases live in `~/.ssh/config` on each operator's workstation, versioned
  in a personal dotfiles repository, never in this one. No private key,
  username, or host detail that counts as a secret goes into `infra`.

## Hardening state (both nodes)

| Directive | File value | Effective (`sshd -T`) |
|---|---|---|
| `PasswordAuthentication` | `no` | `passwordauthentication no` |
| `PubkeyAuthentication` | `yes` | `pubkeyauthentication yes` |
| `PermitRootLogin` | `prohibit-password` | `permitrootlogin without-password` |

This OpenSSH build echoes `prohibit-password` back as `without-password` in the
effective config: same policy, different label.

Password authentication was disabled first. `PermitRootLogin` was tightened from
`yes` to `prohibit-password` afterward, once ordinary operation was confirmed to
never need `root` over SSH: an operator's own account with `sudo` covers every
day to day case, so `root` was narrowed to key only, emergency only, rather
than removed outright.

## Applying an sshd_config change safely

1. Back up before editing: `cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak`.
2. Edit `/etc/ssh/sshd_config`.
3. Validate syntax before touching the running service: `sshd -t`. No output and
   exit code 0 means the file parses.
4. Apply with `systemctl reload ssh`, never `restart`. `reload` makes `sshd`
   re-read its config and apply it to new connections without killing the master
   process or any session already open, so a config change can be pushed to a node
   you are currently connected to without risking a lockout mid edit. `restart`
   tears the daemon down and respawns it; if a mistake slipped past `sshd -t`, or
   the network hiccups during the restart window, the only way in can be lost.
5. Confirm the daemon is healthy: `systemctl status ssh --no-pager` should show
   `Active: active (running)`.
6. Confirm the effective configuration, not just the file, since a failed reload
   can leave file and running daemon out of sync:
   ```bash
   sshd -T | grep -Ei '^(passwordauthentication|pubkeyauthentication|permitrootlogin) '
   ```

## Verification: negative test

Password authentication has to be proven rejected, not assumed from the file. Run
from a separate, already open session, kept alive until the test passes, so a bad
edit does not lock the operator out:

```bash
ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password root@<node-ip>
```

Expected result on both nodes:

```
Permission denied (publickey).
```

The client is forced to offer only password authentication, key auth explicitly
disabled through flags, and the server refuses before ever reaching a password
prompt. That is the proof the policy is enforced server side, not just written
down.

## Emergency access

If key based access to a node is ever lost, the fallback is physical or console
access to the node. SSH password authentication is not, and will not be, a
recovery path. This closes the password guessing surface entirely, at the cost of
requiring physical access to recover from a fully lost key. Both nodes are in the
same location, so the trade-off is accepted.

## References

- ADR 0001: ownership and operational access model
