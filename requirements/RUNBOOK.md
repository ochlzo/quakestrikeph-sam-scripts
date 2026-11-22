# QuakeStrikePH administrator runbook

QuakeStrikePH displays earthquake bulletins and saved forecasts. This runbook
covers the group's `QuakeStrikePH-FreshTest` deployment with sanitized test data.
Use Ubuntu 24.04 LTS on WSL 2 with systemd and root access. The toolkit sets up
Docker Compose, PostgreSQL, Redis, the Backend, Bulletin, and prediction workers
using the prepared offline files.

## Install on a blank FreshTest

1. Gather the preinstall Ubuntu backup, the offline application archive, its
   SHA-256 file, and this repository. The preinstall backup includes the cached
   Docker packages. Follow Steps 1 through 3 of the
   [first-time setup](TESTING-NOTES.md#manual-test-from-a-fresh-import) in Windows
   PowerShell to open the blank FreshTest offline shell.
2. At the FreshTest Linux prompt ending in `~/fresh-test-toolkit#`, run the
   rebuild. It sets up accounts and configuration, installs the app, applies
   final permissions, loads the test data, and verifies the saved forecast.

   ```bash
   time bash quakestrikeph-rebuild.sh --archive /root/quakestrikeph-with-prediction.tar.gz --config /root/fresh-test.env
   ```

3. Look for `Full rebuild successful`. Run the health check below and open the
   [FreshTest website](http://127.0.0.1:24321). Select
   **Sanitized prediction anchor** and check that the forecast details appear.

After a Windows restart, use the [restart checklist](PREPARATION.md) to reopen
the installed environment. The [six-script walkthrough](TESTING.md) and
[manual page](man/quakestrikeph-toolkit.8) document the individual commands.

## Maintenance schedule

| When | What to do |
| --- | --- |
| At the start of each session | Check the six containers, the website, and the saved forecast. |
| Weekly | Check free space with `df -h /tmp /srv /var/lib`. Export a backup to a separate drive and keep its checksum file with it. |
| Before an app or configuration change | Save a known good backup. After the change, repeat the health and forecast checks. |
| Before handing the environment to another administrator | Restore one verified backup in a separate test instance and record the result. |

### Check application health

In the FreshTest Linux shell, run:

```bash
docker --host unix:///var/run/docker.sock ps --filter label=com.docker.compose.project=quakestrikeph-sam
```

Expect PostgreSQL, Redis, Backend API, Bulletin, Dispatcher, and Prediction
Worker to show `(healthy)`. If they are still starting, wait a moment and run
the check again. Windows can reach the [website](http://127.0.0.1:24321) and
[API health endpoint](http://127.0.0.1:23000/healthz).

## Back up FreshTest

Export the populated FreshTest distribution so its app files, database volumes,
configuration, and saved forecast can be restored together. Store the export
and checksum in a private folder on a different drive. The export contains
credentials, so keep it outside Git and the course submission. The preinstall
archive is reserved for blank-server rebuilds. [Microsoft WSL export and import commands](https://learn.microsoft.com/en-us/windows/wsl/basic-commands#export-a-distribution)

1. Schedule a short FreshTest outage. Check the app and note the saved forecast
   before stopping it. At the **FreshTest Linux prompt**, run this block to
   stop Docker and its containers before the file-system export. Proceed when
   it prints `FreshTest Docker stopped for backup.` The check requires Docker
   live restore to be disabled so PostgreSQL stops with Docker.
   [PostgreSQL file-system backups](https://www.postgresql.org/docs/16/backup-file.html)
   · [Docker daemon shutdown behavior](https://docs.docker.com/engine/daemon/live-restore/)

   ```bash
   test "$WSL_DISTRO_NAME" = QuakeStrikePH-FreshTest &&
       test "$(docker --host unix:///var/run/docker.sock info --format '{{.LiveRestoreEnabled}}')" = false &&
       systemctl stop docker.socket docker.service containerd.service &&
       printf '%s\n' 'FreshTest Docker stopped for backup.'
   ```

2. Exit the Linux shell. In **Windows PowerShell**, stop just FreshTest and
   check that its state is `Stopped`. If it already stopped when you exited,
   go directly to the export.

   ```powershell
   wsl.exe --terminate QuakeStrikePH-FreshTest
   wsl.exe --list --verbose
   ```

3. In **Windows PowerShell**, paste the entire block. When prompted, enter the
   full path to an existing private folder on the backup drive. On success,
   PowerShell prints the path of the new dated export.

   ```powershell
   & {
       $backupFolder = Read-Host 'Full path to the private folder on the backup drive'
       if (-not (Test-Path -LiteralPath $backupFolder -PathType Container)) {
           throw 'The backup folder does not exist.'
       }
       $archiveName = 'QuakeStrikePH-FreshTest-{0:yyyy-MM-dd_HHmmss}.tar' -f (Get-Date)
       $archivePath = Join-Path $backupFolder $archiveName
       wsl.exe --export QuakeStrikePH-FreshTest $archivePath
       if ($LASTEXITCODE -ne 0) { throw 'FreshTest export failed.' }
       $hash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256 -ErrorAction Stop).Hash
       Set-Content -LiteralPath ($archivePath + '.sha256') -Value $hash -Encoding Ascii -ErrorAction Stop
       Write-Output $archivePath
   }
   ```

4. Reopen the original FreshTest using the [restart checklist](PREPARATION.md)
   and confirm the six services recover. Keep the `.tar` and `.sha256` together.

## Restore into a separate instance

1. In **Windows PowerShell**, use `wsl.exe --list --verbose` to check that
   `QuakeStrikePH-RestoreTest` is available as a new name. Keep FreshTest
   stopped during the restore check because both instances use Windows ports
   `24321` and `23000`. If FreshTest is running, use the shutdown steps in
   [Back up FreshTest](#back-up-freshtest). These steps target only the test instance.
2. In **Windows PowerShell**, paste the entire block. Enter the populated
   backup's full path and a new, unused folder path such as
   `C:\Users\armen\WSL\QuakeStrikePH-RestoreTest`. The checksum must match before
   WSL imports the file.

   ```powershell
   & {
       $archivePath = Read-Host 'Full path to the populated FreshTest backup tar file'
       $expectedHash = (Get-Content -LiteralPath ($archivePath + '.sha256') -Raw -ErrorAction Stop).Trim()
       $actualHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256 -ErrorAction Stop).Hash
       if ($actualHash -ne $expectedHash) { throw 'Backup checksum mismatch.' }
       $restoreFolder = Read-Host 'Full path to a new folder for QuakeStrikePH-RestoreTest'
       New-Item -ItemType Directory -Path $restoreFolder -ErrorAction Stop | Out-Null
       wsl.exe --import QuakeStrikePH-RestoreTest $restoreFolder $archivePath --version 2
       if ($LASTEXITCODE -ne 0) { throw 'FreshTest backup import failed.' }
   }
   ```

3. Open the restored distribution from **Windows PowerShell**.

   ```powershell
   wsl.exe -d QuakeStrikePH-RestoreTest -u root
   ```

   At the **restored Linux prompt**, start its local services.

   ```bash
   test "$WSL_DISTRO_NAME" = QuakeStrikePH-RestoreTest &&
       systemctl start quakestrikeph-rehearsal-network.service docker.service \
           quakestrikeph-rehearsal-bulletin.socket quakestrikeph-rehearsal-api.socket
   ```

4. Repeat the [health check](#check-application-health) in the restored shell.
   Open the website and API health endpoint from Windows. Compare the restored
   **Sanitized prediction anchor** with the result you noted before the backup.
   Check it before running any rebuild or seed commands so the result reflects
   the restored data. Record the backup date and the restore result.
5. For a restore drill, exit the restored shell and stop it with
   `wsl.exe --terminate QuakeStrikePH-RestoreTest` in PowerShell before reopening
   the original FreshTest. This releases the Windows test ports.

## When something goes wrong

| Symptom | What to check |
| --- | --- |
| Website fails to load | Check the containers and confirm you are viewing port `24321`. Review the Bulletin and Backend logs if either container is unhealthy. |
| Rebuild or seed stops | Read the first failure in the terminal. Check free disk space, that the archive checksum matches, and that the matching private configuration is available. Reuse the existing configuration when retrying. |
| Prediction is missing | Check Dispatcher and Prediction Worker health and logs, then reopen **Sanitized prediction anchor**. |
| Backup hash differs or import fails | Keep the original deployment and archive. Use another verified backup or a new unused restore folder after resolving the reported error. |

For example, check the latest prediction worker messages in the test shell:

```bash
docker --host unix:///var/run/docker.sock logs --tail 50 quakestrikeph-sam-prediction-worker-1
```

## File and log locations

| Location | What it contains |
| --- | --- |
| `/root/fresh-test-toolkit/` | The six course scripts. |
| `/root/quakestrikeph-with-prediction.tar.gz` | The prepared application, model, and Docker image archive. |
| `/var/cache/apt/archives/` | Cached Docker packages used for offline installation. |
| `/root/fresh-test.env` and `/srv/quakestrikeph/.env` | Private external and installed configurations. |
| `/srv/quakestrikeph/` | Installed app files, the generated Compose override, and `bootstrap-snapshots/` evidence. |
| Docker volumes `quakestrikeph-sam_postgres_data` and `quakestrikeph-sam_redis_data` | Local database and cache data. |
| Terminal output and `docker logs` | Script diagnostics and application service logs. |
| Private folder on the backup drive | Dated FreshTest exports, checksum files, and the restore test record. |
