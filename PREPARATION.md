# Reopen FreshTest after restarting Windows

For your completed FreshTest rebuild, run **Commands 1 → 2 → 3** one at a time.
Copy the line below each **COPY AND RUN** label.

## Command 1. Find FreshTest

**▶ COPY AND RUN COMMAND 1 — Windows PowerShell**

```powershell

wsl.exe --list --verbose

```

**Expected output** The list includes `QuakeStrikePH-FreshTest` with version `2`.
`Stopped` is normal after a restart. Continue to Command 2.

## Command 2. Open FreshTest

**▶ COPY AND RUN COMMAND 2 — Windows PowerShell**

```powershell

wsl.exe -d QuakeStrikePH-FreshTest -u root --exec bash -c 'systemctl start quakestrikeph-rehearsal-network.service quakestrikeph-rehearsal-bulletin.socket quakestrikeph-rehearsal-api.socket && cd /root/fresh-test-toolkit && exec nsenter --net=/run/quakestrikeph-rehearsal.netns bash'

```

**Expected output** A Linux prompt ending in `~/fresh-test-toolkit#`.
Run Command 3 at that prompt.

## Command 3. Check the services

**▶ COPY AND RUN COMMAND 3 — FreshTest Linux shell**

```bash

docker --host unix:///var/run/docker.sock ps --filter label=com.docker.compose.project=quakestrikeph-sam

```

**Expected output** Six containers showing `(healthy)` under `STATUS`.
If you see `health: starting`, wait a moment and repeat Command 3.

**Stop after Command 3.** Once all six containers are healthy, open the
[FreshTest website](http://127.0.0.1:24321) in your Windows browser and select
**Sanitized prediction anchor**.

For a brand-new FreshTest, use the
[first-time setup in TESTING.md](TESTING.md#manual-test-from-a-fresh-import).
