# Runbook: Diagnosing a systemd service that fails to start

**Trigger:** `systemctl status <service>` reports `failed`, the service starts and
exits immediately, or `Main PID` shows `code=exited, status=N`.

**Impact if deferred:** depends on the service. A service with `Restart=always`
will keep retrying and eventually hit systemd's start-rate limit, at which point
it stops retrying silently.

**Estimated duration:** 5 to 20 minutes, depending on how deep the root cause is.

## Procedure

### 1. Get a high level view

```bash
systemctl status <service>
```

Read: `Loaded` (whether the unit was found and loaded), `Active` (current state),
`Main PID` (main process and exit status), `ExecStart` (the command systemd is
trying to run), and recent systemd messages. Do not assume the root cause from
`status` alone.

### 2. Narrow with a time window, then by severity

```bash
journalctl -u <service> --since "YYYY-MM-DD HH:MM:SS" --until "YYYY-MM-DD HH:MM:SS"
```

Then, if needed:

```bash
journalctl -u <service> --since "..." --until "..." -p err
```

Use the time window first, to avoid unrelated historical logs drowning out the
incident. If `-p err` hides useful context, remove the severity filter and inspect
the complete window.

### 3. Interpret the exit status

| Status | Meaning |
|---|---|
| `status=127` | Command or executable was not found |
| `status=126` | Command was found but could not be executed |

Distinguish `Failed with result 'exit-code'` (the process exited with a code) from
`Failed with result 'signal'` (the process was terminated by a signal).

### 4. Fix and verify

```bash
sudo systemctl daemon-reload
sudo systemctl start <service>
systemctl status <service>
```

Expected result: `Active: active (running)`, with the corrected `ExecStart` and a
running `Main PID`.

### If the service remains failed

```bash
sudo systemctl reset-failed <service>
sudo systemctl start <service>
```

`reset-failed` is a fallback, not a mandatory step after every failure. A manual
`start` can succeed even after systemd has stopped automatic restart attempts
because of start-rate limiting. `Restart=always` controls automatic restarts after
process termination; the start-rate limit exists precisely to prevent repeated
rapid failures from becoming a crash loop.

## Diagnostic flow

```
systemctl status
      |
read state and ExecStart
      |
journalctl --since ... --until ...
      |
narrow by severity with -p err
      |
interpret status=N plus journal message
      |
fix the root cause
      |
daemon-reload -> start -> status: active (running)
      |
if necessary: reset-failed -> start
```
