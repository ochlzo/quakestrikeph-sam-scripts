# Side-by-side WSL rehearsal

These systemd files are environment preparation for the test distributions.
The instructions below describe the existing `QuakeStrikePH-Rehearsal` setup.
For `QuakeStrikePH-FreshTest`, use the
[manual fresh test guide](../TESTING.md#manual-test-from-a-fresh-import).
Do not install these settings in the working `QuakeStrikePH-Checkoff1` demo.

## Current rehearsal files

The rehearsal's `/root` was tidied on 18 November 2026 without deleting files:

```text
/root/
  rehearsal-toolkit/                        Active scripts, menu, tests, and manuals
  rehearsal.env                            Active private rehearsal configuration
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
firewall rules. The rehearsal uses one private network namespace for Docker,
containerd, and two socket proxies. The existing Compose ports and credentials
stay unchanged.

| Windows address | Destination |
| --- | --- |
| `http://127.0.0.1:4321` | Existing working demo |
| `http://127.0.0.1:14321` | Rehearsal Bulletin, private port 4321 |
| `http://127.0.0.1:13000/healthz` | Rehearsal API, private port 3000 |

The rehearsal addresses serve the application only after a successful rebuild.
The installer still prints its standard port 4321; use **14321** from Windows for
this rehearsal. Container-local health checks remain correct without modification.

## Files and execution order

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
it starts first. Do not restart the namespace service while rehearsal containers
are running. These settings do not modify the demo or global WSL configuration.
The proxy pattern is adapted from the official
[systemd namespace example](https://www.freedesktop.org/software/systemd/man/254/systemd-socket-proxyd.html#Namespace%20Example).
AI assistance was used to prepare these files and verify the setup.

## Apply to another fresh import with the same rehearsal name

Run in Bash as root, from this directory, before installing Docker. The guard
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

## Rebuild when ready

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

This is an actual deployment command, not a preview. Use the separate rehearsal
configuration; do not copy the demo's credentials into it. This also puts the
rebuild process in the private network, so package downloads, image pulls, and
external container connections cannot work; use the prepared archive and cached
packages. The ordinary WSL shell and Windows browser still have their normal
network access, so browser offline behavior needs its own test. These runtime
startup overrides match the cached Ubuntu 24.04 packages; review their vendor
`ExecStart` commands before using different Docker/containerd packages.

## Verification on 18 November 2026

Systemd unit validation passed. Temporary Python HTTP servers in the private
namespace bound ports 3000 and 4321 while the demo continued using the same ports
in the shared namespace. Both forwarded addresses returned the unique rehearsal
test response from WSL and Windows. The proxy and test-server namespace IDs matched
the private namespace and differed from the shared WSL namespace. No external route
existed. WSL subsequently stopped the idle rehearsal distro, removing its transient
test servers. The enabled network and socket units were checked again on startup.

The later real rebuild found a limitation the substitute HTTP servers did not
exercise: setting `PrivateNetwork=yes` directly on Docker/containerd separated
their mount views. Even `/bin/sh` was unavailable when starting a container.
The corrected runtime overrides use `nsenter` for network isolation only. Both
minimal reproductions (the PostgreSQL image entrypoint and an explicit `/bin/sh`
entrypoint) then passed with the original cached image. Network namespace equality
and the absence of an internet default route were rechecked. Restarting the
namespace service while no containers were running also verified recreation of
its `/run/quakestrikeph-rehearsal.netns` link before the runtimes started.

The small regression checks used real containers without application data:

```bash
docker --host unix:///var/run/docker.sock run --rm --network none --pull never \
    postgres:16.15-bookworm postgres --version
docker --host unix:///var/run/docker.sock run --rm --network none --pull never \
    --entrypoint /bin/sh postgres:16.15-bookworm \
    -c 'test -x /usr/local/bin/docker-entrypoint.sh && postgres --version'
```

Both failed before the correction and printed PostgreSQL 16.15 afterward.

The first attempt stopped after 127 seconds. After the environment correction,
the coordinator completed all stages in 118 seconds, including fresh database
migrations, test-data import, and a saved forecast. All six containers were
healthy. Actual Windows requests to both new ports returned HTTP 200; the forecast
page displayed the saved historical SEIS 1.0.1 result. The rebuild process itself
also ran inside the isolated network, with no download fallback. Credentials and
volumes were retained throughout recovery. This was a fresh-environment rehearsal
with a successful recovery, not an uninterrupted clean first attempt.

A full repeat run passed in 126 seconds, retaining four earthquake records, one
successful prediction job, the same event/forecast IDs, and byte-identical private
configurations with unchanged permissions. All six rehearsal containers were
healthy. WSL later stopped the idle distro; its enabled units recovered the
application on startup, and the same database/configuration checks passed again.
This observed WSL recovery is not a Windows reboot test. A hidden WSL keep-alive
process was started for the current session to keep the rehearsal available.
The original demo remained healthy with unchanged container IDs and credentials.

The completed raw logs were moved to `/root/rehearsal-archive/logs/`, retaining
mode 600. They are not copied into Git. Keep a WSL terminal session open while
presenting; systemd services alone do not guarantee that WSL stays running.

## Real uninstall and rebuild test

On 18 November 2026, the user authorized removal of this rehearsal deployment and
its subsequent rebuild. The working demo was excluded. After verifying the distro,
separate Docker engine, installation path, and matching script copies, these
commands were run inside `QuakeStrikePH-Rehearsal`:

```bash
(
    [ "${WSL_DISTRO_NAME:-}" = QuakeStrikePH-Rehearsal ] || exit 1
    bash /root/rehearsal-toolkit/quakestrikeph-uninstall.sh --directory /srv/quakestrikeph
)
```

The preview listed only the six rehearsal containers, two named data volumes,
two project networks, installation directory, and service account/group. The
following confirmed command **deletes the rehearsal database and installed files**:

```bash
(
    [ "${WSL_DISTRO_NAME:-}" = QuakeStrikePH-Rehearsal ] || exit 1
    bash /root/rehearsal-toolkit/quakestrikeph-uninstall.sh --directory /srv/quakestrikeph --confirm
)
```

It passed in 21 seconds. Independent checks verified every targeted resource was
absent, including the service user/group and anonymous volumes. The archive, image
IDs, and external credentials remained unchanged. Repeating the confirmed command
also passed with no resources remaining.

The guarded rebuild command above then passed in 149 seconds, without network
downloads. The database contained four test records, one successful prediction
job, and a new forecast ID. All six containers were healthy, and the Windows
website, API, and new forecast page worked on ports 14321 and 13000. The external
configuration and recreated installed `.env` retained the original credential
bytes, mode 600, and root ownership. The working demo's container IDs/start times,
volumes, networks, and credentials were unchanged; its original ports returned 200.

No course script changes or substitutes were needed. Docker remained installed
with its cached images, as designed; this cycle is distinct from a blank-OS test.
Private logs now reside at `/root/rehearsal-archive/logs/rehearsal-uninstall.Ds5vcV.log`
and `/root/rehearsal-archive/logs/rehearsal-rebuild-after-uninstall.7UVCoS.log`
(mode 600).
