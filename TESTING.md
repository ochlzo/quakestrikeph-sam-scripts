# Testing guide and history

This document contains environment preparation, presentation details, and recorded
tests. For the six scripts and their commands, start with [README.md](README.md).

## Naming

We use **testing** instead of **rehearsal** in the documentation.
The existing WSL name `QuakeStrikePH-Rehearsal`, `/root/rehearsal-toolkit`,
`/root/rehearsal.env`, archive/log paths, and systemd unit names retain their
original spelling. These are working technical identifiers, not instructions to
rename them. No distribution, credentials, or deployment was renamed.

## Manual test from a fresh import

If FreshTest already has a completed rebuild, use the
[restart checklist](PREPARATION.md).

Use `QuakeStrikePH-FreshTest` for the uninterrupted offline rebuild. Its
`/root/fresh-test-toolkit` directory gets only the six course scripts. The
preparation helper runs from the source repository, and the offline app archive
and private configuration are kept outside the toolkit.

Keep these three files in `C:\Users\armen` and keep the scripts repository
available.

- `QuakeStrikePH-Checkoff1-preinstall.tar`
- `quakestrikeph-with-prediction.tar.gz`
- `quakestrikeph-with-prediction.tar.gz.sha256`

Check the WSL list using [Command 1](PREPARATION.md#command-1-find-freshtest).
If FreshTest is missing, start at Step 1. If you imported the backup but
haven't prepared FreshTest yet, start at Step 3. If you already prepared
FreshTest and it is still blank, open it with
[Command 2](PREPARATION.md#command-2-open-freshtest) and go to Step 4.

**1. Create the import folder.** If the folder already exists and is empty, go
to Step 2. If it contains files, check them before importing.

**▶ COPY AND RUN STEP 1 — Windows PowerShell**

```powershell
New-Item -ItemType Directory -Path "C:\Users\armen\WSL\QuakeStrikePH-FreshTest" -ErrorAction Stop
```

Expect PowerShell to list the new folder.

**2. Import the backup.** Run this when FreshTest is missing from the WSL list
and the import folder is empty.

**▶ COPY AND RUN STEP 2 — Windows PowerShell**

```powershell
wsl.exe --import QuakeStrikePH-FreshTest "C:\Users\armen\WSL\QuakeStrikePH-FreshTest" "C:\Users\armen\QuakeStrikePH-Checkoff1-preinstall.tar" --version 2
```

Expect `The operation completed successfully.`

**3. Prepare the test and open the offline shell.**

**▶ COPY AND RUN STEP 3 — Windows PowerShell**

```powershell
wsl.exe -d QuakeStrikePH-FreshTest -u root -- bash "/mnt/c/Users/armen/OneDrive/Desktop/quakestrikeph-sam-scripts/rehearsal-wsl/prepare-fresh-test.sh" --shell "/mnt/c/Users/armen/quakestrikeph-with-prediction.tar.gz"
```

The helper checks the WSL name and clean Ubuntu 24.04 state, copies the six
scripts, verifies the archive checksum, and checks that the private network has
no default route. It then opens Bash in `/root/fresh-test-toolkit` inside that
network. Expect the `Opening the offline shell` message and a root prompt there.
It disables scheduled APT maintenance in FreshTest to preserve the prepared
package cache.
If preparation fails, resolve the reported error before the timed run.

**4. Start the timed rebuild.** Run this from the offline shell on a blank
FreshTest instance. The config script creates `/root/fresh-test.env` during
this run.

If you're unsure whether a rebuild ran, first copy all three lines of this
optional check into the FreshTest Linux shell.

```bash
test ! -e /usr/bin/docker && test ! -e /usr/bin/containerd && \
    test ! -e /srv/quakestrikeph && test ! -e /root/fresh-test.env && \
    echo "FreshTest is blank."
```

If the check prints `FreshTest is blank.`, start the timed run. If the prompt
returns without that message, check the existing installation before proceeding.

**▶ COPY AND RUN STEP 4 — FreshTest Linux shell**

```bash
time bash quakestrikeph-rebuild.sh \
    --archive /root/quakestrikeph-with-prediction.tar.gz --config /root/fresh-test.env
```

Expect all six rebuild stages, the saved forecast message, and exit status `0`
when checked with `echo "$?"`. Record the elapsed time and check the six services
in the same shell.

```bash
docker --host unix:///var/run/docker.sock ps --filter label=com.docker.compose.project=quakestrikeph-sam
```

Check the
[website](http://127.0.0.1:24321) and [API health](http://127.0.0.1:23000/healthz)
from Windows and open the **Sanitized prediction anchor** forecast. The scripts
print the standard internal website port `4321`. FreshTest uses `24321` for the
browser so the existing demo and testing ports stay separate.

The manual setup order is accounts, config, install, accounts again, and seed.
For individual script checks after the timed run, set `archive` and `config` to
the paths in the timed command and use the individual commands in
[README.md](README.md#short-presentation-flow). Preview uninstall only after
showing the forecast. Confirmed removal is for the disposable test deployment.

## Open the testing environment

The following steps open the existing `QuakeStrikePH-Rehearsal` instance.

From PowerShell:

```powershell
wsl -d QuakeStrikePH-Rehearsal -u root
```

Then in WSL:

```bash
if [ "${WSL_DISTRO_NAME:-}" != QuakeStrikePH-Rehearsal ]; then
    echo "Wrong distribution. Stopping."
    exit 1
fi
cd /root/rehearsal-toolkit || exit 1
nsenter --net=/run/quakestrikeph-rehearsal.netns bash
```

Stop if entering the network fails. Keep the terminal open. This Bash session
uses the private network without an internet route; the six scripts are in the
current directory. Follow the individual commands in [README.md](README.md).
The separate working-demo distribution is `QuakeStrikePH-Checkoff1`.

## Optional presentation menu

From PowerShell:

```powershell
wsl -d QuakeStrikePH-Rehearsal -u root -- bash /root/rehearsal-toolkit/presentation-menu.sh
```

Choose one script at a time. The helper supplies paths and the offline network,
shows original output and exit status, and stops on failure. Installation includes
the required final permissions pass. Uninstall previews its targets and requires
typing `REMOVE` before deletion. Choose `0` to exit. It is a convenience helper,
separate from the six course scripts; it does not reduce deployment runtime.

## Presentation sequence

The group's chosen approach demonstrates all six scripts separately. For the
actual Option 1C presentation, start full rebuild on a blank platform first,
then demonstrate the individual scripts' repeat-safe behavior:

1. Full rebuild.
2. Accounts.
3. Configuration.
4. Installation, followed by accounts for final permissions.
5. Seed, then show the website and saved forecast.
6. Uninstall preview; confirmed removal only on the authorized disposable deployment.

Confirmed uninstall leaves that deployment uninstalled. The preserved inputs can
be used to rebuild it later. Practicing on the currently installed environment
demonstrates repeat safety; it does not supply the blank-platform starting state.

Faculty guide Sections 3.4, 5.5, and 7.2 specify a blank VM with cached packages
allowed, a 20-minute slot (normally 12 presentation/demo + 8 questions), and allow
the Option 1C rebuild to run through the whole slot. Our README previously recorded
approval for Ubuntu 24.04 WSL 2 at Check-off 1; do not infer additional platform or
presentation approvals from this. Keep the faculty-supplied guide with the group's
course materials.

## WSL environment details

### Current testing files

The testing environment's `/root` was tidied on 18 November 2026 without deleting files:

```text
/root/
  rehearsal-toolkit/                        Active scripts, menu, tests, and manuals
  rehearsal.env                            Active private testing configuration
  quakestrikeph-with-prediction.tar.gz       Complete offline application archive
  quakestrikeph-with-prediction.tar.gz.sha256
  rehearsal-archive/                       Older preparation files and logs
  demo.env                                 Preserved inherited configuration
```

Use `rehearsal.env` for this deployment. The inherited `demo.env` was preserved
unchanged. The archive folder contains six verified duplicate former `/root`
script copies in `scripts/`, five completed test logs in `logs/`, and the older
`quakestrikeph.tar.gz` in `bundles/`. No disk-space savings are claimed: these files
were moved, not deleted. `/root` now has six visible entries instead of seventeen.

Run the six scripts from `/root/rehearsal-toolkit`, where they stay together for
the rebuild coordinator. The presentation menu command is unchanged. Tests, the
manual, and WSL setup files retain their existing relative locations. Checks after
the move passed script syntax/help, test syntax, manual rendering, and menu exit;
no installation, seeding, or removal was run for this cleanup. Preserved inputs
and moved files were checked for unchanged contents, permissions, and ownership.

Both distributions share WSL's host network. Different published web ports alone
would still leave two Docker engines managing the same network interfaces and
firewall rules. The testing environment uses one private network namespace for Docker,
containerd, and two socket proxies. The existing Compose ports and credentials
stay unchanged.

| Windows address | Destination |
| --- | --- |
| `http://127.0.0.1:4321` | Existing working demo |
| `http://127.0.0.1:14321` | Testing Bulletin, private port 4321 |
| `http://127.0.0.1:13000/healthz` | Testing API, private port 3000 |

The testing addresses serve the application only after a successful rebuild.
The installer still prints its standard port 4321; use **14321** from Windows for
this rehearsal. Container-local health checks remain correct without modification.

### Files and execution order

1. `quakestrikeph-rehearsal-network.service` holds the private network open using
   `sleep infinity`. It starts with only a loopback interface and no internet route.
2. `private-network.conf`, installed as a drop-in for both `docker.service` and
   `containerd.service`, orders them after the network service. The matching
   `docker-network.conf` and `containerd-network.conf` wrap their existing startup
   commands with `nsenter`, entering only the private network. Their local Unix
   sockets and separate distro storage remain available. Both runtimes must share
   the host mount view: using `PrivateNetwork=yes` directly on them gave them
   separate mount views and caused container entrypoint files to be inaccessible.
3. The two `.socket` units listen on the new host ports. A connection starts the
   matching `quakestrikeph-rehearsal-proxy@.service` instance, which forwards into
   the private network. The proxy uses systemd already present in the backup.

`BindsTo` stops dependent services if the namespace service stops; `After` ensures
it starts first. Do not restart the namespace service while testing containers
are running. These settings do not modify the demo or global WSL configuration.
The proxy pattern is adapted from the official
[systemd namespace example](https://www.freedesktop.org/software/systemd/man/254/systemd-socket-proxyd.html#Namespace%20Example).
AI assistance was used to prepare these files and verify the setup.

### Apply to another fresh import with the same WSL name

Run in Bash as root, from the `rehearsal-wsl/` directory, before installing Docker. The guard
refuses another distro or an already installed Docker engine. Ports 13000 and
14321 must be free; a socket start failure must be resolved before rebuilding.

```bash
(
    set -e
    [ "${WSL_DISTRO_NAME:-}" = QuakeStrikePH-Rehearsal ]
    [ "$EUID" -eq 0 ]
    [ ! -e /usr/bin/docker ]
    [ ! -e /srv/quakestrikeph ]
    install -d -m 755 /etc/systemd/system/docker.service.d /etc/systemd/system/containerd.service.d
    install -m 644 quakestrikeph-rehearsal-network.service quakestrikeph-rehearsal-proxy@.service \
        quakestrikeph-rehearsal-bulletin.socket quakestrikeph-rehearsal-api.socket /etc/systemd/system/
    install -m 644 private-network.conf /etc/systemd/system/docker.service.d/private-network.conf
    install -m 644 private-network.conf /etc/systemd/system/containerd.service.d/private-network.conf
    install -m 644 docker-network.conf /etc/systemd/system/docker.service.d/runtime-network.conf
    install -m 644 containerd-network.conf /etc/systemd/system/containerd.service.d/runtime-network.conf
    systemctl daemon-reload
    systemctl enable --now quakestrikeph-rehearsal-network.service \
        quakestrikeph-rehearsal-bulletin.socket quakestrikeph-rehearsal-api.socket
)
```

### Rebuild when ready

Open `wsl -d QuakeStrikePH-Rehearsal -u root` from PowerShell. In that distro:

```bash
(
    [ "${WSL_DISTRO_NAME:-}" = QuakeStrikePH-Rehearsal ] || exit 1
    network_pid=$(systemctl show -p MainPID --value quakestrikeph-rehearsal-network.service)
    [ "$network_pid" -gt 0 ] || exit 1
    nsenter -t "$network_pid" -n bash /root/rehearsal-toolkit/quakestrikeph-rebuild.sh \
        --archive /root/quakestrikeph-with-prediction.tar.gz \
        --config /root/rehearsal.env \
        --directory /srv/quakestrikeph
)
```

This is an actual deployment command, not a preview. Use the separate testing
configuration; do not copy the demo's credentials into it. This also puts the
rebuild process in the private network, so package downloads, image pulls, and
external container connections cannot work; use the prepared archive and cached
packages. The ordinary WSL shell and Windows browser still have their normal
network access, so browser offline behavior needs its own test. These runtime
startup overrides match the cached Ubuntu 24.04 packages; review their vendor
`ExecStart` commands before using different Docker/containerd packages.

## Offline preparation

Prepare the following inputs before the presentation. These packaging commands run in the separate application source checkout, not in the scripts repository. APT cache preparation runs on the target server.

## Prepare the clean server

Use a separate fresh Ubuntu 24.04 server with systemd and root access. Do not use the existing working-demo distribution as a clean server.

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

## Recorded outcomes on 18 November 2026

These are results of the recorded runs, not a live health report.

| Check | Result |
| --- | --- |
| First attempt from the preinstall backup | Stopped after 127 seconds on a runtime mount-isolation issue. |
| Retry after correcting the environment | All rebuild stages passed in 118 seconds. |
| Complete repeat run | Passed in 126 seconds; records, forecast ID, and credentials were preserved. |
| Real clean uninstall | Passed in 21 seconds; targeted containers, volumes, networks, files, and account were absent. |
| Uninstall with nothing remaining | Passed again. |
| Rebuild after uninstall | Passed in 149 seconds; generated a fresh database and forecast using the preserved credentials. |

The real database checks found four earthquake records, one successful prediction
job, and one saved forecast. All six containers were healthy at verification.
Windows website/API requests and saved-forecast pages passed on ports 14321/13000.
During those tests, the working demo's container IDs/start times, volumes, networks,
and credential bytes/permissions remained unchanged.

The first failure came from applying `PrivateNetwork=yes` directly to Docker and
containerd: their separate mount views made container entrypoints, including
`/bin/sh`, inaccessible. The corrected overrides use network-only `nsenter`.
The same images then passed both minimal reproductions:

```bash
docker --host unix:///var/run/docker.sock run --rm --network none --pull never \
    postgres:16.15-bookworm postgres --version
docker --host unix:///var/run/docker.sock run --rm --network none --pull never \
    --entrypoint /bin/sh postgres:16.15-bookworm \
    -c 'test -x /usr/local/bin/docker-entrypoint.sh && postgres --version'
```

The coordinator and Docker ran without an internet default route. Docker/packages
remained installed after uninstall by design, so that cycle was not another
blank-OS installation. WSL later stopped the idle testing distro; enabled services
recovered its application on startup. This was not a Windows reboot test.

Menu checks used substitutes for systemd/network/script dispatch to verify every
choice, argument, failure stop, and uninstall confirmation/cancellation. A real
preview-and-cancel check also passed; no confirmed removal ran during menu testing.
A later read-only check during menu work encountered a WSL timeout for the working
demo and unavailable ports 4321/3000. No reset was performed. Historical successful
tests should not be interpreted as a guarantee of its present availability.

The tidy-up moved six duplicate script copies, five logs, and an older archive
into `/root/rehearsal-archive`. No files were deleted. Hashes, ownership, and modes
were checked, and script syntax/help, test syntax, manual rendering, and menu exit
passed afterward.

Private raw logs are retained under `/root/rehearsal-archive/logs/` with mode 600.
They are outside Git and may contain operational details; do not publish them
without reviewing for credentials.

## Remaining verification

- An uninterrupted first run on another fresh import with the corrected network setup.
- A Windows reboot and recovery test.
- Browser behavior with internet disconnected, including external map tiles and sign-in.
- Timing the entire sequence when demonstrating all six scripts separately.

The complete bundle and all 17 required cached package files were checked before
the initial installation. A later package/image/release change needs its own checks.

## Automated checks

Run tests deliberately on the authorized testing environment. Some create
temporary fixtures, and the accounts test creates/reuses the actual service account.

| Test | Scope |
| --- | --- |
| `tests/check-scripts.sh` | Syntax/help/arguments and installer preflight/failure simulations. |
| `tests/check-accounts.sh` | Real service identity and file-permission checks. |
| `tests/check-config.sh` | Configuration validation/reuse; checks existing demo files when present. |
| `tests/check-uninstall.sh` | Removal simulations with substituted Docker/account/removal commands. |
| `tests/check-rebuild.sh` | Coordinator simulations; real config generation in temporary fixtures. |
| `tests/check-compose-environment.sh` | Real Compose parsing with temporary credentials; no services started. |

## Earlier verification recorded on 18 November 2026

These entries preserve the earlier testing record. Statements below that a fresh install or uninstall was still pending describe that earlier point in time; the later real results above supersede those statements.

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
offline testing, first-run execution of the new seed script against an empty
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

