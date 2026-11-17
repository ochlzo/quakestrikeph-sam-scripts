# QuakeStrikePH SAM scripts

Administration scripts for the IT 123 final project, Option 1C, Provision and Rebuild.

The current installer sets up the local QuakeStrikePH website, Backend, PostgreSQL, and Redis on Debian 13 with systemd.
It uses cached Debian packages and a prepared application archive for offline installation.

## Current status

`quakestrikeph-install.sh` is implemented. The other five Option 1C scripts remain planned.
Those scripts cover accounts and permissions, configuration setup, database seed or restore, clean uninstall, and full rebuild.

Completed checks include Bash syntax, Compose configuration validation, and simulated installation, repeat-run, and failure paths.
Actual package installation, database initialization, and application responses still need verification on the group's clean server.
Faculty approval for Debian and WSL as the presentation environment remains unconfirmed.

## Read the script

Run these commands in Bash from this repository's root.

```bash
bash -n quakestrikeph-install.sh
bash quakestrikeph-install.sh --help
```

The first command checks syntax. The second prints usage and preparation requirements.
Both commands can run as a regular user.

## Prepare the clean server

Use the group's dedicated Debian 13 environment with systemd enabled and working `sudo` access.
The current development environment is the separate WSL 2 distribution named `QuakeStrikePH-SAM`.
The installer also targets Debian 13 machines that provide the same requirements.

Before the offline demonstration, prepare the package cache on that clean server.

1. Refresh the package lists while internet access is available.

   ```bash
   sudo apt-get update
   ```

2. If the refresh succeeds, download Docker and its dependencies.

   ```bash
   sudo apt-get install --download-only docker.io docker-cli docker-compose
   ```

APT stores these files in `/var/cache/apt/archives/`. Installation happens when the installer runs.
Prepare the cache for each target server's Debian version, architecture, and existing package state.
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

9. Create the final archive outside this scripts repository.

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
```

Include the remaining tracked application files exported by Git.
Keep credentials and real client or user records outside the archive.
Supply only the group's trusted archive to the installer.

## Prepare the private configuration

Create a separate `demo.env` using the application checkout's `.env.example` as a reference.
Supply valid demonstration settings and distinct database passwords.
Keep this file outside the scripts repository and application archive.

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
Add `--directory /your/dedicated/path` to select another destination.

The installer runs these operations in order.

1. Validate arguments, privileges, tools, configuration, and archive contents.
2. Install Docker from the local package cache and start its service.
3. Load the prepared Docker images and copy application files.
4. Start PostgreSQL and Redis under the Compose project `quakestrikeph-sam`.
5. Create database roles, apply migrations, and register and verify the model release.
6. Start the Backend and Bulletin and check both HTTP responses.

Success prints the application directory and `http://127.0.0.1:4321`.
Open that address on the server's host machine. Remote access requires a separately configured connection.
Failures print an explanation and exit with a nonzero status.

Repeated runs with the same prepared release and configuration reuse database volumes.
The installer stops the web services before applying migrations again.
It rejects a configuration that differs from an existing installed `.env`.
A failed run may leave services stopped or initialization partly completed. Correct the reported problem before retrying.

The database seed or restore script will supply demonstration earthquake records.
Background ingestion, prediction, and alert delivery require their separate application setup.

## Honesty and safe practice

Disclose AI assistance in each script's comment block and credit copied or adapted code above the relevant code.
Every group member must be able to explain every script line during individual questions.
Use the group's VM and test data, and keep scripts and reports private to the group.
These practices follow Section 5.6 of the IT 123 project guide supplied with the course materials.

## Contributing

Keep Bash files in LF format and follow the existing readable `if`, `then`, and `fi` style.
Read `AGENTS.md` before changing scripts with an agent.
Record the checks performed and distinguish simulations from actual server tests.
