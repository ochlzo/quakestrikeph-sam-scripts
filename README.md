# QuakeStrikePH SAM scripts

Administration scripts for the IT 123 final project, Option 1C, Provision and Rebuild.

The installer targets Ubuntu 24.04 LTS and Debian 13 with systemd for the local QuakeStrikePH website, Backend, PostgreSQL, and Redis.
It uses cached APT packages and a prepared application archive for offline installation.

## Current status

All six scripts are implemented: installation, accounts, configuration, seed, clean uninstall, and full rebuild.
Clean uninstall and an already-removed repeat run have passed against actual Docker
resources in `QuakeStrikePH-Rehearsal`. The working demo was not uninstalled.
The subsequent offline rebuild also passed, recreating the database and saved
forecast while reusing the preserved external configuration.
Full rebuild has run against actual Docker and PostgreSQL in the separately imported
`QuakeStrikePH-Rehearsal` environment. Its first attempt stopped on a rehearsal
networking/mount configuration issue; after correcting that environment, a retry
completed all stages and saved the forecast without resetting data or credentials.
The seed script imports the reviewed historical test fixture; it is not a general backup restore tool.

Completed checks include Bash syntax, Compose configuration validation, and simulated installation, repeat-run, and failure paths.
The group has exercised real Docker services, PostgreSQL, test-data import, and a completed forecast on its demo instance.
The rehearsal began with Docker and the application absent, using cached packages
and the prepared archive. The rebuild process and Docker ran without an internet
route. An uninterrupted first attempt on another fresh import remains unverified;
the completed rehearsal included recovery from the environment issue.
The group has faculty approval to use a fresh Ubuntu 24.04 LTS instance under WSL 2 for Check-off 1.

## Read the script

For the current WSL rehearsal, use `/root/rehearsal-toolkit` as the active script
folder. Duplicate former `/root` script copies, older logs, and the older bundle
were moved into `/root/rehearsal-archive`; nothing was deleted. Current archive
and configuration paths are unchanged. See the
[rehearsal file layout](rehearsal-wsl/README.md#current-rehearsal-files).

Run these commands in Bash from this repository's root.

```bash
bash -n quakestrikeph-install.sh
bash quakestrikeph-install.sh --help
bash -n quakestrikeph-seed.sh
bash quakestrikeph-seed.sh --help
bash -n quakestrikeph-accounts.sh
bash quakestrikeph-accounts.sh --help
bash -n quakestrikeph-config.sh
bash quakestrikeph-config.sh --help
bash -n quakestrikeph-uninstall.sh
bash quakestrikeph-uninstall.sh --help
bash -n quakestrikeph-rebuild.sh
bash quakestrikeph-rebuild.sh --help
```

The first command checks syntax. The second prints usage and preparation requirements.
Both commands can run as a regular user.
All six scripts include a header usage instruction and a concrete `--help` example.
The uninstall example previews removal; it does not include `--confirm`.

## Read the manual page

The section-8 manual covers all six scripts, their options, execution order,
examples, important files, exit statuses, and current testing limits.
Open it from this repository's root in Ubuntu (no root privileges required):

```bash
man ./man/quakestrikeph-toolkit.8
```

Press `q` to leave the viewer. The manual uses the nine sections required by
Section 5.2 and Appendix C of the faculty project guide. Keep the `man/` directory
in the submission package. Reading this page does not execute any script.
The page was rendered with `man` and `groff` without warnings on 18 November 2026;
all six scripts also passed syntax and help checks. No deployment commands ran.

## Prepare the clean server

Use the group's dedicated Ubuntu 24.04 WSL 2 instance, `QuakeStrikePH-Checkoff1`, with systemd enabled and root or `sudo` access.

Before the offline demonstration, prepare the package cache on that clean server.

1. Refresh the package lists while internet access is available.

   ```bash
   sudo apt-get update
   ```

2. If the refresh succeeds, download Docker and its dependencies for your distribution.

   ```bash
   # Ubuntu 24.04 (Check-off 1)
   sudo apt-get install --download-only docker.io docker-compose-v2
   ```

   On Debian 13, use `sudo apt-get install --download-only docker.io docker-cli docker-compose` instead.

APT stores these files in `/var/cache/apt/archives/`. Installation happens when the installer runs.
Prepare the cache for each target server's distribution, version, architecture, and existing package state.
WSL distributions and ordinary Linux machines keep separate package caches.

Allow space for the source archive, temporary extraction, Docker images, and database volumes.
The installer temporarily extracts the complete archive under `/tmp`.

## Prepare the application archive

Use a separate working QuakeStrikePH checkout with internet access and Docker available.
Follow the application's local runtime guide to configure that checkout and package the reviewed model release.
Use a clean, reviewed Git commit for both the source export and image builds.
The application repository contains the complete model preparation instructions. [QuakeStrikePH repository](https://github.com/ochlzo/quakestrikeph)

Run the following commands from that application checkout in Bash.
Check each command's result before continuing.

1. Build the three local application images.

   ```bash
   docker compose --env-file .env \
       -f infrastructure/compose.yml \
       -f infrastructure/compose.backend.yml \
       -f infrastructure/compose.local.yml \
       build local-init backend-api bulletin
   ```

2. Download the database and Redis images.

   ```bash
   docker compose --env-file .env -f infrastructure/compose.yml pull postgres redis
   ```

3. Create a temporary bundle directory.

   ```bash
   bundle_directory=$(mktemp -d)
   ```

4. Export the tracked source files from the reviewed commit.

   ```bash
   git archive --format=tar --output="$bundle_directory/source.tar" HEAD
   ```

5. Extract those source files into the bundle directory.

   ```bash
   tar -xf "$bundle_directory/source.tar" -C "$bundle_directory"
   ```

6. Remove the intermediate source archive.

   ```bash
   rm -- "$bundle_directory/source.tar"
   ```

7. Copy the packaged model files into the bundle directory.

   ```bash
   cp -a model-artifacts "$bundle_directory/model-artifacts"
   ```

8. Export the five required images into the bundle directory.

   ```bash
   docker image save --output "$bundle_directory/images.tar" \
       postgres:16.15-bookworm redis:7.4.11-bookworm \
       quakestrike-workers:local quakestrike-backend:local quakestrike-bulletin:local
   ```

9. Build and save the separate prediction image while internet is available.

   ```bash
   docker build --build-arg BASE_IMAGE_TAG=local --tag quakestrike-prediction:local \
       --file workers/prediction-worker/Dockerfile .
   docker image save --output "$bundle_directory/prediction-image.tar" quakestrike-prediction:local
   ```

   This adds the locked prediction dependencies and `libgomp1` to the same worker image.
   Do not build or download these during the offline demonstration.

10. Create the final archive outside this scripts repository.

   ```bash
   tar -czf ./quakestrikeph.tar.gz -C "$bundle_directory" .
   ```

The image names above match the application files inspected for this installer.
If the application changes an image tag, prepare matching images and review the installation procedure again.
The Bulletin image must use the development stage selected by `compose.local.yml`.

The archive must contain these paths directly at its root.

```text
apps/
database/
infrastructure/
model-artifacts/
  seis-1.0.1/
    manifest.json
    models/
packages/
workers/
images.tar
prediction-image.tar
```

Include the remaining tracked application files exported by Git.
Keep credentials and real client or user records outside the archive.
Supply only the group's trusted archive to the installer.
Include `infrastructure/compose.release.yml` and `workers/tests/fixtures/bootstrap/historical_snapshot.json`.
Never include the runtime `bootstrap-snapshots/` directory: its run manifest belongs to a specific database.
The installer generates `infrastructure/compose.checkoff.yml`; the earlier manual
`compose.checkoff-prediction.yml` is retained only as historical preparation evidence and is not used by these scripts.

## Prepare the private configuration

Run the configuration script as root in Ubuntu before installation:

```bash
sudo bash quakestrikeph-config.sh --output /root/demo.env --directory /srv/quakestrikeph
```

Its execution order is deliberately simple:

1. If the output file exists, validate it and leave every byte and its permissions unchanged.
2. If output is absent but the installation has an `.env`, copy that existing configuration into a new private output file.
3. If neither exists and there is no installed check-off configuration, generate four distinct passwords with OpenSSL and write matching local database URLs.

When both files exist, they must match exactly, consistent with the installer's
repeat-run check. A conflict, invalid file, duplicate required key, or an existing
installation missing its credentials causes a clear failure; the script never
repairs an existing file or rotates its passwords. It does not read the downloaded
credential file, print passwords, source `.env` as shell commands, or start services.

New files are root-owned with mode 600 and LF line endings. The output's parent must
already be a root-owned Linux directory that is not writable by group or others.
Existing files must be root-owned with mode 600 or 400. Symlinks and hard links are
rejected. New configuration is first written privately and published without
overwriting a file that another process might have created meanwhile.

This is a configuration generator for the current SEIS 1.0.1 historical demo, not
a general production configuration editor. Its constants come from the application
template and reviewed fixture. Validation expects the demo's 64-character hexadecimal
password format, matching role URLs, and the packaged release/date. Other formats
are rejected unchanged. Optional sign-in/provider credentials are omitted from new
files; an existing file's optional settings and comments are retained verbatim.

Keep this file outside Git and the application archive. Use the resulting file as
the installer's `--config` input. The installed copy remains separate.

The installer checks these settings before installing packages.

| Setting | Requirement |
| --- | --- |
| `POSTGRES_PASSWORD`, `MIGRATION_DB_PASSWORD`, `WORKER_DB_PASSWORD`, `BACKEND_DB_PASSWORD` | Nonempty values that match the corresponding database URLs. |
| `MIGRATION_DATABASE_URL`, `DATABASE_URL`, `BACKEND_DATABASE_URL` | Private container address `postgres:5432/quakestrike`, with the appropriate database login. |
| `MODEL_RELEASE_ID` | The ID from the reviewed model bundle. |
| `BACKEND_IMAGE_TAG` | A nonempty value. The local Compose override selects the `:local` image. |
| `PHIVOLCS_CATALOG_URL` | The approved catalog URL required by the application configuration. |
| `MODEL_ARTIFACT_HOST_DIRECTORY` | Exactly `../model-artifacts`. |
| `REDIS_URL` | Exactly `redis://redis:6379/0`. |
| `BOOTSTRAP_REQUIRED_AVAILABLE_THROUGH` | For the bundled demo fixture: `2026-09-01T00:00:00+08:00`. |

Use plain `KEY=value` lines with LF line endings for the checked settings.
Keep `POSTGRES_DB` and `POSTGRES_USER` at their application defaults, `quakestrike`, if you include them.
Account features additionally require the application's development provider settings and an internet connection.

Protect the configuration file on the target server.

```bash
chmod 600 demo.env
```

The installer accepts input permissions `600` or `400` and stores the installed `.env` with permissions `600`.

## Run the installer

Transfer the application archive and private configuration to the prepared server first.
Run the installer on the group's server with test data.

```bash
sudo bash quakestrikeph-install.sh \
    --archive /path/to/quakestrikeph.tar.gz \
    --config /path/to/demo.env
```

Replace the example paths with the transferred files' actual locations.
The default application directory is `/srv/quakestrikeph`.
Add `--directory /srv/NAME` to select another dedicated destination directly under `/srv`.
The installer rejects parent directories, symlink paths, mounted targets or children,
linked files, and unrelated nonempty directories before package or service changes.
A nonempty destination must be a recognized course installation with its original `.env`.

The installer runs these operations in order.

1. Validate arguments, privileges, tools, configuration, and archive contents.
2. Install Docker from the local package cache and start its service.
3. Load both image archives, copy application files, and generate the check-off Compose override.
4. Start PostgreSQL and Redis under the Compose project `quakestrikeph-sam`.
5. Create database roles, apply migrations, grant worker permissions, and register and verify the model release.
6. Start the Backend and Bulletin and check both HTTP responses.

Success prints the application directory and `http://127.0.0.1:4321`.
Open that address on the server's host machine. Remote access requires a separately configured connection.
Failures print an explanation and exit with a nonzero status.

Repeated runs with the same prepared release and configuration reuse database volumes.
The installer stops web and background services before applying migrations again.
If bootstrap evidence already exists, it checks readiness and restarts Dispatcher and Prediction Worker.
It does not enable recurring ingestion, Beat, or alert delivery.
It rejects a configuration that differs from an existing installed `.env`.
Installation, seeding, and the rebuild's final checks run Compose with a small,
explicit environment: `PATH`, `HOME`, the native local Docker socket, and the two
fixed worker image/bootstrap settings. Exported shell passwords, database URLs,
and other application settings cannot override the supplied `.env`. Set application
values in the private configuration file, not with shell exports. This does not
edit the calling shell or either configuration file. Installer image loading uses
the same native local Docker engine as Compose.
A failed run may leave services stopped or initialization partly completed. Correct the reported problem before retrying.

## Create the service account and apply permissions

Run this before installation to create the locked account and an empty application
directory. Run it again after every installation to protect the deployed files:

```bash
sudo bash quakestrikeph-accounts.sh --directory /srv/quakestrikeph
```

Use a dedicated directory directly under `/srv`, such as `/srv/quakestrikeph`.
The accounts script deliberately rejects Windows paths, symlinks, hard-linked files,
mounted filesystems within its target, and unrelated nonempty directories. It never
changes the Docker-managed database volumes.

The service user and group are both named `quakestrikeph`, with UID/GID 10001 to
match the existing worker image. The account has a locked password, `/nonexistent`
home, and `/usr/sbin/nologin` shell. It is not added to sudo or Docker groups. An
existing compatible identity is reused; conflicting names or IDs cause a failure
instead of changing an unrelated account.

| Files or directories | Owner/group | Permissions |
| --- | --- | --- |
| Application directories | `root:quakestrikeph` | `750` |
| Application files | `root:quakestrikeph` | `640` |
| Shell scripts | `root:quakestrikeph` | `750` |
| Installed `.env` | `root:root` | `600` |
| Bootstrap evidence directories | `quakestrikeph:quakestrikeph` | `700` |
| Bootstrap evidence files | `quakestrikeph:quakestrikeph` | `600` |

The worker can read application files and write its evidence, but cannot change
code or read the host `.env`. Root runs Compose and supplies the needed settings
to containers. The upstream Bulletin **development** image currently runs as root;
this script does not change container users or claim to harden that image. The
Backend retains its existing `node` user and PostgreSQL retains its own database
identity. Do not recursively change ownership of Docker's volume directories.

The installer still applies its initial file permissions when copying a release.
The full-rebuild script runs the scripts in this order:
**accounts → configuration → installation → accounts → seed**, then checks HTTP responses.
The same order applies when running the scripts individually.

## Full rebuild

`quakestrikeph-rebuild.sh` is the main rebuild command. Run it as root from the
prepared Linux toolkit with the offline archive and private config path. The
[Script 1 command for FreshTest](TESTING.md#script-1-full-rebuild) starts the
timed rebuild and verifies the app.

### Short presentation flow

For the [manual fresh test](TESTING-NOTES.md#manual-test-from-a-fresh-import),
prepare `QuakeStrikePH-FreshTest` and run each script directly from the
[six-script walkthrough](TESTING.md).

The faculty guide (Sections 3.4 and 7.2) requires starting the full rebuild on a
blank VM at the beginning of the slot. The slot is 20 minutes, normally 12 for
presentation/demonstration and 8 for questions; Option 1C's rebuild may use the
whole slot. Cached packages are allowed, but the application platform must not
already be installed on that blank machine.

The group's selected presentation approach runs all six scripts separately.
Start full rebuild first, then demonstrate the individual scripts' repeat-safe
behavior. Use the existing default application directory, `/srv/quakestrikeph`,
and set the two input paths once to shorten the commands. Complete the guarded
WSL/offline-shell preparation in [the rehearsal instructions](rehearsal-wsl/README.md)
first; these examples are for that authorized rehearsal only.

```bash
cd /root/rehearsal-toolkit
archive=/root/quakestrikeph-with-prediction.tar.gz
config=/root/rehearsal.env
```

Run each command individually and inspect its success message and exit status
before proceeding. `echo "$?"` immediately after a script must print `0`.

| Order | Command | What to explain |
| --- | --- | --- |
| 1 | `bash quakestrikeph-rebuild.sh --archive "$archive" --config "$config"` | Runs the complete sequence and verifies the saved forecast. |
| 2 | `bash quakestrikeph-accounts.sh` | Reuses the dedicated account and applies permissions. |
| 3 | `bash quakestrikeph-config.sh --output "$config"` | Validates and preserves the private configuration. |
| 4 | `bash quakestrikeph-install.sh --archive "$archive" --config "$config"` | Repeats deployment while preserving the existing database. |
| Permission pass | `bash quakestrikeph-accounts.sh` | Reapplies final permissions after installation copies files. |
| 5 | `bash quakestrikeph-seed.sh` | Reuses the reviewed test records and verifies the forecast. |
| 6, after showing the website | `bash quakestrikeph-uninstall.sh` | Previews exactly what will be removed. |

Only after showing the website and forecast, run the confirmed uninstall on the
disposable rehearsal if removal is part of the demonstration:

```bash
if [ "${WSL_DISTRO_NAME:-}" = QuakeStrikePH-Rehearsal ]; then
    bash quakestrikeph-uninstall.sh --confirm
else
    echo "Wrong distribution; uninstall not run."
fi
```

This final command leaves the rehearsal application uninstalled. It retains the
archive and external configuration for a later rebuild. Use ports 14321/13000
before uninstalling. The working demo remains on its original ports.
Practicing this sequence on the currently installed rehearsal demonstrates repeat
safety; it does not provide the blank-platform starting state required for the
actual presentation. Prepare a separate fresh import for that starting state.

Recent successful rebuilds took 118–149 seconds and uninstall took 21 seconds.
These are measured rehearsal results, not a guarantee for a fresh VM or a timing
of the entire individual-script sequence. Running both rebuild and installation
separately necessarily repeats deployment work. Explain the scripts while those
operations run. Keep the existing validation and readiness checks. No script
behavior was changed to shorten this presentation flow.
For the prepared `QuakeStrikePH-Rehearsal` distribution running alongside the working
demo, use the [rehearsal network setup](rehearsal-wsl/README.md). It gives the second
Docker engine a private network and forwards Bulletin to Windows port **14321**
and the API to **13000**, keeping the six scripts and demo credentials unchanged.
This setup has passed the real Docker/application rebuild after correcting the
runtime mount isolation issue. A separate WSL distribution alone
does not isolate networking from the working demo.

Keep the toolkit scripts together outside the installation directory. On a separately
prepared disposable server with the cached packages and complete archive described
above, the rebuild command is:

```bash
sudo bash quakestrikeph-rebuild.sh \
    --archive /root/quakestrikeph-with-prediction.tar.gz \
    --config /root/demo.env \
    --directory /srv/quakestrikeph
```

This is a deployment command, not a preview. Do not use the working demo for a fresh
rehearsal. A different `--directory` is not an isolated deployment: the scripts use
the fixed Compose project `quakestrikeph-sam`. Use a separate server/WSL distribution.

`--archive` is required. The other options default to the paths shown above.
The script checks the archive's readability/integrity, target paths, sibling script
syntax, and existing credential conflicts before starting its stages. The installer
still checks the bundle's required contents before installing packages. The config
script performs full configuration validation before installation.

Before checking the archive and running the deployment stages, the rebuild prints
`df -h -- /tmp /srv /var/lib`. This shows filesystem size, used space, and available
space for temporary extraction, application files, and default Docker storage.
`-h` formats sizes in readable units. A failed query stops the rebuild before any
stage runs. This is a resource report, not a minimum-space guarantee; required space
depends on the prepared release. Under WSL, check Windows drive space separately
because the virtual filesystem can report more free capacity than the host has.
The `df` command in `quakestrikeph-rebuild.sh` provides the resource-check location
for the future Skills Map.

Execution order:

1. Create or reuse the dedicated account and application directory.
2. Validate/reuse the private configuration. If its external copy is missing, recover
   the installed copy; generate credentials only for a new setup.
3. Run the existing offline installer, including database/schema/model setup.
4. Apply final permissions after installation has copied the files.
5. Run the existing seed script, which waits for a successful saved forecast.
6. Check Backend and Bulletin HTTP responses again from inside their containers.

All stages use the native local Docker socket. An inherited remote Docker context
or TLS setting is cleared for this process and its children, not changed globally.
The script never invokes uninstall. A repeat run reuses credentials and data, but
the installer briefly stops application services while applying database setup.
Use the same reviewed release and matching configuration for a repeat run.

The first failure stops later stages and returns status 1 with the child's diagnostic
and the failed stage. Earlier changes are not rolled back. Correct the reported
problem before retrying; do not delete volumes or regenerate credentials to retry.
Status 0 means the seed's saved-forecast check and both final HTTP checks passed.
These container-local HTTP checks do not prove Windows localhost forwarding or
offline map/sign-in access; verify the browser separately.

## Load and verify the demo forecast

After a successful installation and permissions pass, run the seed script from this scripts repository:

```bash
sudo bash quakestrikeph-seed.sh --directory /srv/quakestrikeph
```

The script verifies the exact SHA-256 of the reviewed fixture, imports it through
the application's bootstrap command, checks startup readiness, and starts Dispatcher
and Prediction Worker with cached images. It waits up to five minutes for a saved
successful forecast. Failure at any step returns nonzero; a healthy container alone
is not reported as forecast success.

The fixture has nine input rows, including a duplicate and four deliberately invalid
rows. A fresh import stores four earthquake records and queues one prediction.
The validation warnings belong to the test fixture. They are not live download failures.
Repeated seed runs reuse the persisted run and records. Do not delete the run manifest
while keeping its database, or copy it into a fresh database's bundle.

The override mounts the private evidence directory at the original
`/app/workers/bootstrap-snapshots` path used by the manual import. The worker image's
UID/GID 10001 owns that directory with mode 700. Runtime workers mount it read-only.
The installed `.env` remains root-readable with mode 600. The accounts script creates
the matching host identity and applies final source/evidence permissions.

Bulletin now uses `restart: unless-stopped`, like the other long-running demo services.
Keep the interactive WSL session open for the presentation. Docker restart policy
does not itself start a stopped WSL distribution or prove Windows localhost forwarding.

Open `http://127.0.0.1:4321`, select **Sanitized prediction anchor**, and verify forecast
results. Its September 2026 forecast window is historical and correctly shows **Ended**.
For the offline browser check, disconnect internet only for that test and reconnect
after capturing evidence. Map tiles may depend on external services or browser cache;
this test does not prove every map tile or sign-in feature works offline.

Installation followed by seeding reproduces the current demo setup. Full rebuild
coordinates those steps with accounts and configuration; clean uninstall remains a
separate operation. Six implemented scripts alone do not prove a blank-server rebuild.

## Clean uninstall

`quakestrikeph-uninstall.sh` removes the dedicated course deployment. It does not
invoke Compose files or source credentials; it identifies resources using their
exact Compose project label, checks container working-directory labels, and only
accepts the expected PostgreSQL and Redis named volumes. It targets the local
`/var/run/docker.sock` so a selected remote Docker context is not used.

Preview is the default. On the authorized disposable deployment, inspect it first:

```bash
sudo bash quakestrikeph-uninstall.sh --directory /srv/quakestrikeph
```

**Destructive command — do not run on the working demo.** Once a real uninstalltest is explicitly authorized and needed data is backed up, `--confirm` enables deletion:

```bash
sudo bash quakestrikeph-uninstall.sh --directory /srv/quakestrikeph --confirm
```

The script validates the directory, mounts, resource ownership, and service identity
before making changes. It stops/removes the project containers and their anonymous
storage, removes the two labelled data volumes and project networks, removes the
installed directory, then removes the matching service user/group. Docker refuses
removal of resources that are still in use; the script does not force that removal.
It verifies that the targeted resources are absent before reporting success.

| Removed with `--confirm` | Retained |
| --- | --- |
| Course project containers and associated anonymous volumes | Other projects' resources |
| `quakestrikeph-sam_postgres_data` and `quakestrikeph-sam_redis_data` | Docker packages and cached images |
| Course project networks | Application/image archives and database backups outside the installation directory |
| Installed application directory, its `.env`, and bootstrap evidence | Separate `/root/demo.env`, downloaded credentials, and scripts repository |
| Matching `quakestrikeph` service account/group | Unrelated accounts/groups |

Repeated uninstalls accept already-absent resources. Docker must still be available
to verify that the database is gone. If resources remain but the installation files
have disappeared or do not match, the script refuses to guess: restore the known
installation files for inspection first. If a removal fails partway through, stop
and inspect the reported resource; earlier removals are not rolled back. A later
retry can continue after the specific failure is corrected.

This script supports one dedicated deployment with the fixed course project name.
It deliberately has no global prune, image-removal, package-removal, or forced
account-deletion command. Preserve the separate demo configuration for rebuilding.
For Docker's distinction between anonymous and named volume removal, see
[container removal](https://docs.docker.com/reference/cli/docker/container/rm/).

## Offline rehearsal recorded on 18 November 2026

`QuakeStrikePH-Rehearsal` was imported from the preinstall backup with Docker and
the application absent. The first rebuild installed the cached packages and loaded
all six images, then stopped after 127 seconds because containers could not see
their entrypoint files. The initial `PrivateNetwork=yes` runtime overrides also
created separate mount views for Docker and containerd. Replacing those overrides
with network-only `nsenter` startup commands fixed the issue; both minimal container
reproductions passed using the same images. No database volume or configuration
was deleted or replaced.

The coordinator then completed all six stages in 118 seconds. Actual PostgreSQL
contained four earthquake records, one successful prediction job, and one saved
forecast. All six application containers were healthy. Windows HTTP requests to
ports 14321 and 13000 succeeded, and the forecast page showed the saved SEIS 1.0.1
result for Sanitized prediction anchor. Its historical window correctly read Ended.

A complete repeat run then passed in 126 seconds. Database counts, the anchor
event ID, and the forecast ID stayed identical; both rehearsal configuration files
retained their bytes and permissions. After WSL automatically stopped the idle
rehearsal, its enabled services started again and all six containers returned to
healthy status. A WSL keep-alive process was started for the current presentation
session. Windows checks passed on all four demo/rehearsal ports. The working demo's
container IDs and credential bytes/permissions remained unchanged.
Both the coordinator and Docker ran in the rehearsal namespace with no default
internet route. This validates rebuilding from local inputs; Windows itself stayed
online, so this does not claim that external map tiles or sign-in work offline.
The original demo remained healthy and its credential bytes and permissions were
checked separately. The six course scripts required no changes for this rehearsal.
See [the rehearsal setup](rehearsal-wsl/README.md) for the environment correction
and the guarded deployment command.

## Real uninstall and rebuild recorded on 18 November 2026

With explicit authorization, the uninstall script was previewed and then run with
`--confirm` only in `QuakeStrikePH-Rehearsal`, after checking its distinct Docker
engine and exact `/srv/quakestrikeph` target. It completed in 21 seconds. Independent
checks found no project containers, volumes, or networks, no installation directory,
and no service user/group. The engine had no remaining volumes, including anonymous
ones. The archive, cached image IDs, and external credential bytes/permissions/owners
were unchanged. A second confirmed uninstall also succeeded with nothing to remove.

The existing full-rebuild script then passed in 149 seconds with no internet route.
It recreated the service account, files, database, and test records using the same
external configuration. Actual PostgreSQL contained four earthquake records, one
successful prediction job, and a newly generated forecast. All six containers were
healthy. Windows HTTP checks passed on 14321 and 13000, including the API event and
the new saved-forecast page. The original demo also returned HTTP 200 on 4321/3000;
its container IDs/start times, networks, volumes, and credentials were unchanged.

These were actual Docker/PostgreSQL checks, with no command substitutes. No course
script changes were needed. Docker packages and images were retained by uninstall,
so this verifies the uninstall/rebuild cycle, not another blank-OS installation.
The README, manual, and rehearsal notes were updated and copied into the rehearsal
toolkit. Private raw logs remain outside Git in the rehearsal's `/root` directory.

## Earlier verification recorded on 18 November 2026
The following entries describe checks made before the separate rehearsal above.
Run the non-installing checks in Ubuntu:

```bash
bash tests/check-scripts.sh
```

These passed Bash syntax, help output, argument rejection, missing-image preflight,
and image-load failure propagation. The package, systemd, and Docker commands in the
failure-path test are substitutes; those checks do not prove a real installation.

Separately, the updated installer was run successfully against the existing
`QuakeStrikePH-Checkoff1` environment with the new application archive. The seed script
then succeeded twice against actual Docker and PostgreSQL. Four earthquake records,
one prediction job, and the same forecast ID were preserved. All six demo services
were healthy. Windows requests to the homepage and saved forecast page returned HTTP
200, and the forecast page contained the saved result instead of “Forecast processing”.
The installed configuration was mode 600, the evidence folder mode 700 owned by
10001:10001, and Bulletin's restart policy was `unless-stopped`.

This verification used an existing database and available Docker packages. It did
not disconnect the computer, reset WSL, or perform a blank-server install. A fresh
offline rehearsal, first-run execution of the new seed script against an empty
database, reboot recovery, and verification of the complete toolkit
remain separate verification/work items. The earlier manual first import and offline
browser demonstration do not replace those updated-script checks.

The accounts script was subsequently tested with real user/group creation in this
demo instance and temporary file fixtures under `/srv`:

```bash
sudo bash tests/check-accounts.sh
```

This integration test creates/reuses the real `quakestrikeph` account. It verifies
repeat runs before and after deployment, unsafe-path/link rejection, root-only
configuration, service-readable but non-writable code, and service-writable evidence.
The script was then applied twice to the real application. Seeding and readiness
still passed after applying the permissions. These tests do not reset the server.
Use the application's health command for the running prediction worker; the
`startup-check` CLI writes an operator manifest and belongs in the writable
`release-init` container, not the worker's read-only evidence mount.

Configuration setup checks can be run in the demo environment:

```bash
sudo bash tests/check-config.sh
```

The test generates temporary credentials, verifies distinct passwords and matching
URLs, checks 600/400 permissions and unchanged repeat runs, recovers a missing output
from an installed test configuration, and rejects conflicts, invalid files, duplicate
keys, symlinks, and missing installed credentials. An OpenSSL command substitute
tests random-generator failure and temporary-file cleanup. Real Compose accepted the
generated configuration with `config --quiet`; no services were started with it.
When the real `/root/demo.env` and `/srv/quakestrikeph/.env` exist, the test also runs
the configuration script twice and compares their before/after hashes without
printing hashes or credentials. Both real files remained byte-identical on
18 November 2026. A new configuration still needs a fresh-server installation test.

Clean-uninstall simulations are available separately:

```bash
sudo bash tests/check-uninstall.sh
```

The test substitutes Docker, account lookup/deletion, and filesystem-removal commands.
Its guarded removal substitute can delete only the harness's temporary `/srv` fixture.
No real Docker or user/group deletion is performed. Tests cover preview, confirmation,
repeat execution, wrong container directory, account mismatch, mounted paths, unavailable
Docker, unexpected volume names, root-path rejection, and failure/retry after a refused
volume removal. These simulations passed; an actual uninstall on a separately authorized
disposable deployment and a subsequent rebuild remain unverified. The working demo
has not been uninstalled or stopped for these tests.

Full-rebuild coordinator checks:

```bash
sudo bash tests/check-rebuild.sh
```

These checks passed on 18 November 2026. The harness copies the coordinator beside
substitute accounts, installation, and seed scripts, and intercepts every Docker
call. It runs the real configuration script only against private temporary test
files. It checks stage order and arguments (including paths containing spaces),
local Docker selection, repeated runs, credential preservation/recovery, failure
at each stage and HTTP check, and rejection of invalid inputs, missing scripts,
or lost/conflicting installed credentials. No real service account, Docker service,
database, or demo configuration was changed. Shared syntax/help/argument checks
also cover the sixth script. A timed fresh offline rebuild and actual uninstall
on a separate disposable deployment remain unverified.

## Safety regression checks recorded on 18 November 2026

```bash
sudo bash tests/check-scripts.sh
sudo bash tests/check-rebuild.sh
sudo bash tests/check-compose-environment.sh /path/to/quakestrikeph
```

The updated script checks passed, including rejection of `/etc`, parent/nested paths,
unrelated files, symlinks, hard links, and a simulated mounted child before any
package/service calls. Empty, absent, and recognized temporary destinations reached
archive validation; image-load failure still stopped before deployment copying.
Package, service, Docker, and mounted-path commands were substituted where needed.
The rebuild coordinator's existing order, failure, and credential-preservation tests
also passed with substitutes.
The help checks require an example from every script. Rebuild tests use real `df`
for the disk report and a failing substitute to verify that a resource-query error
stops execution before any lifecycle stage.

The Compose environment test uses the application source's Compose files and private
temporary credentials. It loads only each script's `compose()` function and runs real
`docker compose config` twice with deliberately conflicting exported passwords/URLs.
All three functions resolved the file's values, and the temporary configuration copies
remained identical. This is configuration parsing, not a real installation, seed,
or database test. The working demo and its credentials were not changed. A fresh
offline installation and real repeat-run verification remain pending.

## Honesty and safe practice

Disclose AI assistance in each script's comment block and credit copied or adapted code above the relevant code.
Every group member must be able to explain every script line during individual questions.
Use the group's VM and test data, and keep scripts and reports private to the group.
These practices follow Section 5.6 of the IT 123 project guide supplied with the course materials.

## Contributing

Keep Bash files in LF format and follow the existing readable `if`, `then`, and `fi` style.
Read `AGENTS.md` before changing scripts with an agent.
Record the checks performed and distinguish simulations from actual server tests.
