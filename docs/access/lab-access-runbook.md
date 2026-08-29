# Lab Access Runbook — SSH (pve1 / pve2)

**Scope:** key-based SSH access to the two Proxmox nodes of the Asymptora homelab,
current hardening state, and the tmux ritual for long-running remote work.
**Nodes covered:** `pve1` (192.168.1.10), `pve2` (192.168.1.11)
**Module:** 7 — SSH and remote operations

---

## 1. Access model

- Authentication is by SSH key only — **ed25519**, no passwords, anywhere, for anyone.
- Daily operations run as `cazuza` + `sudo`. `root` over SSH exists only for emergencies
  and is never reachable by password (see §2).
- Host aliases (`ssh pve1`, `ssh pve2`) live in `~/.ssh/config`, versioned in the
  `dotfiles` repo — never here. No private key, no host detail that counts as a secret,
  ever goes into `infra`.

## 2. sshd_config — hardening directives (final state, both nodes)

| Directive | File value | Effective (`sshd -T`) |
|---|---|---|
| `PasswordAuthentication` | `no` | `passwordauthentication no` |
| `PubkeyAuthentication` | `yes` | `pubkeyauthentication yes` |
| `PermitRootLogin` | `prohibit-password` | `permitrootlogin without-password` |

> This OpenSSH build echoes `prohibit-password` back as `without-password` in the
> effective config — same policy, different label. Don't be thrown by the mismatch
> between what you wrote and what `sshd -T` prints back.

**History, in one line:** password authentication was disabled first (proof in §3);
`PermitRootLogin` was tightened from `yes` to `prohibit-password` afterward, once it
was clear normal operation never needs `root` over SSH — `cazuza` + `sudo` covers
every day-to-day case, so `root` was narrowed to "key-only, emergency-only" rather
than removed outright.

### Applying a change safely

1. **Back up before editing**: `cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak`
   (done on both nodes before this change).
2. Edit `/etc/ssh/sshd_config`.
3. **Validate syntax before touching the running service**: `sshd -t` — no output
   and exit code 0 means the file parses.
4. **Apply with `systemctl reload ssh`, never `restart`.** `reload` makes `sshd`
   re-read its config and apply it to new connections without killing the master
   process or any session already open — you can push a config change to a node
   you're *currently* connected to without risking a lockout mid-edit. `restart`
   tears the daemon down and respawns it; if a mistake slipped past `sshd -t`, or
   the network hiccups during the restart window, you can lose your only way in.
5. Confirm the daemon is healthy: `systemctl status ssh --no-pager` →
   `Active: active (running)`.
6. Confirm the **effective** configuration, not just the file (a failed reload can
   leave file and running daemon out of sync):
   ```
   sshd -T | grep -Ei '^(passwordauthentication|pubkeyauthentication|permitrootlogin) '
   ```

## 3. Proof — negative test

Password auth has to be proven rejected, not just assumed from the file. Run from a
**separate, already-open session** (kept alive until the test passes, so a bad edit
doesn't lock you out):

```
ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password root@192.168.1.10
ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password root@192.168.1.11
```

Result, both nodes:

```
Permission denied (publickey).
```

The client is forced to offer *only* password authentication (key auth explicitly
turned off via flags), and the server refuses before it ever gets to a password
prompt. That's the proof the policy is enforced server-side, not just written down.

## 4. tmux — the daily ritual

Any SSH session can die mid-work — a Wi-Fi hiccup, a sleeping laptop, a terminal
closed by reflex. Whatever runs in the foreground of that session dies with it: it's
a child process of the SSH session, and when the parent dies, `sshd` sends it
`SIGHUP`. `tmux` breaks that dependency by keeping the session alive on the server,
as a child of the `tmux` server process — independent of whatever SSH connection is
currently looking at it.

| Action | Command |
|---|---|
| Create a named session | `tmux new -s <name>` |
| Detach (leave it running) | `Ctrl+b`, then `d` |
| Reattach | `tmux attach -t <name>` (or `tmux a -t <name>`) |
| New window in current session | `Ctrl+b c` |
| Switch window | `Ctrl+b n` / `Ctrl+b p` / `Ctrl+b <number>` |
| List running sessions | `tmux ls` |
| Bypass the prefix (from inside an active `$TMUX` shell) | `tmux <command>` — talks to the session over its socket, no keybinding needed; useful when the local terminal eats `Ctrl+b` |

### Evidence — survival test

**Without tmux (baseline):** plain SSH session to `pve1`, started an unsaved edit,
killed the terminal tab by force (not `exit`). On reconnecting, both the session and
the process running inside it were gone — matches the `SIGHUP`-on-parent-death model.

**With tmux:** `ssh pve1` → `tmux new -s edicao` → unsaved edit started inside the
session → detached with `Ctrl+b d` → terminal tab killed by force again → new
terminal, `ssh pve1`, `tmux attach -t edicao`. The session and the unsaved buffer
inside it were exactly as left.

**Multiple windows:** from inside `edicao`, `tmux new-window` (invoked directly via
the session's socket, prefix bypassed because it collided with a local shortcut)
created a second window in the same session, same host. Status bar confirmed three
windows in the session (`0:bash 1:bash- 2:bash*`), each resolving to `pve1` via
`hostname` — proof the windows live inside the server session, not in separate local
terminal tabs.

## 5. File transfer — rsync vs scp

`scp` copies unconditionally: source to destination, every byte, every time,
regardless of whether the destination already holds an identical copy. Fine for a
one-off single file. `rsync` compares source and destination first (size + mtime by
default, checksum with `-c`) and transfers only what changed. For any repeated sync —
a working copy kept current on a server, incremental backups, the deploy flow coming
in Module 10 — `rsync -av` is the standard; `scp` stays reserved for a single one-off
copy where the delta doesn't matter.

## 6. Editor availability — vi vs vim

`vim` (the full package, with the `vim` binary/alias) is **not** installed by default
on either node — Proxmox's minimal Debian base doesn't ship it. That does not make
`vi` obsolete: `vi`, the ancestor `vim` is built on, is a POSIX-mandated utility —
any Unix-like system claiming POSIX compliance has to ship *some* `vi`. Confirmed on
both nodes:

```
$ which vi; command -v vi
/usr/bin/vi
/usr/bin/vi
```

**Practical takeaway:** don't assume `vim` on a server you don't control — assume
`vi`. Its coverage is broader than `vim` or `nano` (`nano` is a GNU project, not
guaranteed outside GNU-lineage distros), which is exactly why "vi survival" is the
safer skill to bank on. Installing the full `vim` package on `pve1`/`pve2` — from the
official repository, per the Module 5 source-trust policy — is a deliberate future
action, not a blocker: it's tracked, not done.

## 7. Emergency access

If key-based access to a node is ever lost, the fallback is physical/console access
to the node (keyboard+monitor, or the Proxmox web console) — SSH password
authentication is not, and will not be, a recovery path. This closes the
password-guessing surface entirely, at the cost of requiring physical access to
recover from a fully lost key. Both nodes live in the same house, so that trade-off
is acceptable at this stage of the lab.

---

*Module 7 — SSH and remote operations. Criterion met: key-based access working on
both nodes with password authentication disabled (`root` via `prohibit-password`
only); tmux fluency demonstrated with evidence — survival of forced disconnection,
multiple windows, reconnection.*
