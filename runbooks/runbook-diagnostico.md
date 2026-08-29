# Runbook — Diagnosing a systemd Service That Fails to Start

## Symptom

Typical signs:

* `systemctl status <service>` shows `failed`
* The service starts and exits immediately
* `Main PID` shows `code=exited, status=N`

## First command

Start with:

```bash
systemctl status <service>
```

Use it to get a high-level view:

* `Loaded` — whether the unit was found and loaded
* `Active` — current service state
* `Main PID` — main process and exit status
* `ExecStart` — command systemd is trying to run
* Recent systemd messages

Do not assume the root cause from `status` alone.

## Where to look next

Start with a **time window**, then narrow by severity:

```bash
journalctl -u <service> \
  --since "YYYY-MM-DD HH:MM:SS" \
  --until "YYYY-MM-DD HH:MM:SS"
```

Then, if needed:

```bash
journalctl -u <service> \
  --since "YYYY-MM-DD HH:MM:SS" \
  --until "YYYY-MM-DD HH:MM:SS" \
  -p err
```

Use the time window first to avoid unrelated historical logs drowning out the incident.

If `-p err` hides useful context, remove the severity filter and inspect the complete window.

## Exit status quick reference

Interpret the exit status together with the journal message.

* `status=127` — command or executable was not found **(observed in today's incident)**
* `status=126` — command was found but could not be executed **(reference, not observed today)**

Example:

```text
Main process exited, code=exited, status=127
```

If the journal also shows:

```text
/bin/bash: /path/to/script.sh: No such file or directory
```

the missing script or path is the immediate cause.

Also distinguish:

```text
Failed with result 'exit-code'
```

from:

```text
Failed with result 'signal'
```

The first indicates that the process exited with an exit code; the second indicates termination by a signal.

## Fix and verify

After correcting the root cause:

```bash
sudo systemctl daemon-reload
sudo systemctl start <service>
systemctl status <service>
```

Expected result:

```text
Active: active (running)
```

The final `status` should also show the corrected `ExecStart` and a running `Main PID`.

### If the service remains failed

If a manual `start` does not work because the unit remains in a failed state, clear the failed state and try again:

```bash
sudo systemctl reset-failed <service>
sudo systemctl start <service>
```

`reset-failed` is a fallback, not a mandatory step after every failure. A manual `systemctl start` can succeed even after systemd has stopped automatic restart attempts because of start-rate limiting.

`Restart=always` controls automatic restarts after process termination. The systemd start-rate limit prevents repeated rapid failures from creating a crash loop.

## Diagnostic flow

```text
systemctl status
        ↓
read the state and ExecStart
        ↓
journalctl --since ... --until ...
        ↓
narrow by severity with -p err
        ↓
interpret status=N + journal message
        ↓
fix the root cause
        ↓
daemon-reload
        ↓
start
        ↓
status → active (running)
        ↓
if necessary: reset-failed → start
```

