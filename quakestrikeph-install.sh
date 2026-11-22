#!/bin/bash

# Install QuakeStrikePH on the course server
# Authors: Armenta, Buergo, Candelaria, Pispis
# Usage: bash quakestrikeph-install.sh --help
# AI assistance: ChatGPT explained Bash syntax and completed this script
# using the group's existing style. The group must understand every line.
# Sources: QuakeStrikePH docs/operations/local-runtime.md, web and worker setup;
# https://docs.docker.com/reference/cli/docker/compose/up/
# https://docs.docker.com/reference/cli/docker/compose/run/
# https://manpages.debian.org/trixie/apt/apt-get.8.en.html

app_directory="/srv/quakestrikeph"
app_archive=""
config_file=""

fail()
{
    echo "Installation failed: $*" >&2
    exit 1
}

while [ "$#" -gt 0 ]
do
    if [ "$1" = "--help" ]
    then
        echo "Usage: sudo bash quakestrikeph-install.sh --archive FILE --config FILE [--directory PATH]"
        echo "Install the QuakeStrikePH local web application on Ubuntu 24.04 or Debian 13 with systemd."
        echo ""
        echo "Options:"
        echo "  --archive FILE    Prepared offline application archive (.tar.gz)."
        echo "  --config FILE     Private demo environment file with permissions 600 or 400."
        echo "  --directory PATH  Dedicated /srv/NAME directory. Default: /srv/quakestrikeph"
        echo "  --help            Show this help message and exit."
        echo ""
        echo "Example:"
        echo "  sudo bash quakestrikeph-install.sh --archive ./quakestrikeph.tar.gz --config ./demo.env"
        echo ""
        echo "Prepare before the offline rebuild:"
        echo "  Ubuntu 24.04: apt-get install --download-only docker.io docker-compose-v2"
        echo "  Debian 13: apt-get install --download-only docker.io docker-cli docker-compose"
        echo "  Put the repository contents directly at the archive root, without a parent folder."
        echo "  Include model-artifacts/, images.tar, and prediction-image.tar in that archive."
        echo "  Create images.tar with docker image save from the same working checkout."
        echo "  Include PostgreSQL, Redis, quakestrike-workers:local, quakestrike-backend:local,"
        echo "  and the development-stage quakestrike-bulletin:local image used by compose.local.yml."
        echo "  Save quakestrike-prediction:local separately in prediction-image.tar."
        echo "  Include infrastructure/compose.release.yml and the bundled historical test fixture."
        echo "  Use a dedicated installation directory and your group's trusted archive."
        echo "  Keep .env outside the archive. Supply a separate test-only configuration file."
        echo ""
        echo "This installs Bulletin, Backend, PostgreSQL, and Redis and initializes their schema."
        echo "Run quakestrikeph-seed.sh afterward to import demo records and start predictions."
        exit 0

    elif [ "$1" = "--directory" ] || [ "$1" = "--archive" ] || [ "$1" = "--config" ]
    then
        if [ "$#" -lt 2 ] || [ -z "$2" ] || [[ "$2" == --* ]]
        then
            echo "Error: $1 requires a value."
            exit 1
        fi

        if [ "$1" = "--directory" ]
        then
            app_directory="${2%/}"
        elif [ "$1" = "--archive" ]
        then
            app_archive="$2"
        else
            config_file="$2"
        fi
        shift 2

    else
        echo "Error: unknown option '$1'. Use --help."
        exit 1
    fi
done

# Check if may root access
if [ "$EUID" -ne 0 ]
then
    echo "Run this script with root privileges."
    exit 1
fi

# Check the required tools muna before changing the server
for required_command in apt-get systemctl realpath tar mktemp stat grep cp chmod install cmp find findmnt env
do
    if ! command -v "$required_command" > /dev/null
    then
        echo "Installation failed: $required_command is required."
        exit 1
    fi
done

if [ ! -d /run/systemd/system ]
then
    echo "Installation failed: start the server with systemd enabled."
    exit 1
fi

if ! source /etc/os-release
then
    echo "Installation failed: could not read /etc/os-release."
    exit 1
fi

# Choose Docker packages ayon sa Linux release
if [ "$ID" = "ubuntu" ] && [ "$VERSION_ID" = "24.04" ]
then
    docker_packages=(docker.io docker-compose-v2)
elif [ "$ID" = "debian" ] && [ "$VERSION_ID" = "13" ]
then
    docker_packages=(docker.io docker-cli docker-compose)
else
    echo "Installation failed: use Ubuntu 24.04 or Debian 13."
    exit 1
fi

if [ ! -f "$app_archive" ] || [ ! -r "$app_archive" ]
then
    echo "Installation failed: use --archive to supply a readable application archive."
    exit 1
fi

if [ ! -f "$config_file" ] || [ ! -r "$config_file" ]
then
    echo "Installation failed: use --config to supply a readable demo environment file."
    exit 1
fi

config_permissions=$(stat -c '%a' -- "$config_file")
if [ "$config_permissions" != "600" ] && [ "$config_permissions" != "400" ]
then
    echo "Installation failed: give the private configuration file permissions 600 or 400."
    exit 1
fi

# Check the destination muna before changing the server
[[ "$app_directory" =~ ^/srv/[a-zA-Z0-9._-]+$ ]] || fail "choose a dedicated /srv/NAME directory."
[ "$(realpath -m -- "$app_directory")" = "$app_directory" ] || fail "do not use dot segments or symlink paths."
[ ! -L "$app_directory" ] || fail "the application directory must not be a symlink."
[ ! -e "$app_directory" ] || [ -d "$app_directory" ] || fail "the target is not a directory."

mounted_paths=$(findmnt -rn -o TARGET) || fail "could not inspect mounted filesystems."
while IFS= read -r mounted_path
do
    case "$mounted_path" in
        "$app_directory"|"$app_directory"/*) fail "unmount $mounted_path before installing." ;;
    esac
done <<< "$mounted_paths"

if [ -d "$app_directory" ]
then
    first_entry=$(find "$app_directory" -mindepth 1 -maxdepth 1 -print -quit) || fail "could not inspect the directory."
    if [ -n "$first_entry" ]
    then
        [ -f "$app_directory/infrastructure/compose.checkoff.yml" ] &&
        [ -f "$app_directory/apps/quakestrikeph-bulletin/package.json" ] ||
            fail "nonempty directory is not an installation from the updated installer."
        [ -f "$app_directory/.env" ] || fail "installation is missing its .env; recover the original credentials first."
    fi
    linked_file=$(find "$app_directory" -xdev \( -type l -o \( -type f -links +1 \) \) -print -quit) ||
        fail "could not inspect links."
    [ -z "$linked_file" ] || fail "review linked file before proceeding: $linked_file"
fi

# Keep existing database credentials kapag reinstalling
if [ -f "$app_directory/.env" ] && ! cmp -s -- "$config_file" "$app_directory/.env"
then
    echo "Installation failed: this directory already has a different configuration."
    echo "Use its original configuration for a repeated installation."
    exit 1
fi

# Read credentials as data lang from the private configuration
for setting in POSTGRES_PASSWORD MIGRATION_DB_PASSWORD WORKER_DB_PASSWORD BACKEND_DB_PASSWORD MODEL_RELEASE_ID BACKEND_IMAGE_TAG PHIVOLCS_CATALOG_URL BOOTSTRAP_REQUIRED_AVAILABLE_THROUGH
do
    if ! grep -Eq "^${setting}=.+" "$config_file"
    then
        echo "Installation failed: $setting needs a value in the configuration file."
        exit 1
    fi
done

for setting in MIGRATION_DATABASE_URL DATABASE_URL BACKEND_DATABASE_URL
do
    if ! grep -Eq "^${setting}=postgresql(\+psycopg)?://[^[:space:]]+@postgres:5432/quakestrike$" "$config_file"
    then
        echo "Installation failed: $setting must use the demo database at postgres:5432/quakestrike."
        exit 1
    fi
done

if ! grep -qx 'MODEL_ARTIFACT_HOST_DIRECTORY=../model-artifacts' "$config_file" ||
   ! grep -qx 'REDIS_URL=redis://redis:6379/0' "$config_file"
then
    echo "Installation failed: use ../model-artifacts for model storage and redis://redis:6379/0 for Redis."
    exit 1
fi

# Check the offline archive muna before installing packages
if ! staging_directory=$(mktemp -d /tmp/quakestrikeph-install.XXXXXX)
then
    echo "Installation failed: could not create a temporary directory."
    exit 1
fi
trap 'rm -rf -- "$staging_directory"' EXIT

# Use local ownership and permission defaults muna
if ! tar --extract --gzip --file "$app_archive" --directory "$staging_directory" --no-same-owner --no-same-permissions
then
    echo "Installation failed: could not extract the application archive."
    exit 1
fi

for required_file in infrastructure/compose.yml infrastructure/compose.backend.yml \
    infrastructure/compose.local.yml infrastructure/compose.release.yml \
    workers/tests/fixtures/bootstrap/historical_snapshot.json database/initialization/provision-roles.sh \
    apps/quakestrikeph-bulletin/package.json model-artifacts/seis-1.0.1/manifest.json images.tar prediction-image.tar
do
    if [ ! -f "$staging_directory/$required_file" ]
    then
        echo "Installation failed: the archive is missing $required_file at its root."
        exit 1
    fi
done

if [ ! -d "$staging_directory/model-artifacts" ] || [ -e "$staging_directory/.env" ]
then
    echo "Installation failed: include model-artifacts/ and keep .env outside the archive."
    exit 1
fi

# Keep saved evidence sa deployment that owns the database
if [ -e "$staging_directory/bootstrap-snapshots" ]
then
    echo "Installation failed: keep bootstrap-snapshots/ out of the application archive."
    exit 1
fi

# Adapted from the application release Compose mounts para sa offline demo
# Use relative paths para custom install directories work
if ! cat > "$staging_directory/infrastructure/compose.checkoff.yml" <<'YAML'
# AI-assisted course override; application service definitions remain upstream.
services:
  bulletin:
    restart: unless-stopped
  release-init:
    volumes:
      - ../bootstrap-snapshots:/app/workers/bootstrap-snapshots
  dispatcher:
    environment:
      ALERT_RESOLUTION_ENABLED: "false"
    volumes:
      - ../bootstrap-snapshots:/app/workers/bootstrap-snapshots:ro
  prediction-worker:
    volumes:
      - ../bootstrap-snapshots:/app/workers/bootstrap-snapshots:ro
YAML
then
    echo "Installation failed: could not prepare the check-off Compose configuration."
    exit 1
fi

# Use cached Docker packages para offline ang install
# Use the same local Docker engine para sa images and Compose
export DOCKER_HOST=unix:///var/run/docker.sock
unset DOCKER_CONTEXT DOCKER_TLS_VERIFY DOCKER_CERT_PATH DOCKER_TLS

echo "Installing Docker from cached packages..."
if ! apt-get --no-download install -y "${docker_packages[@]}"
then
    echo "Installation failed: could not install Docker from cached packages."
    exit 1
fi

# Start Docker and enable it para ready at boot
if ! systemctl enable --now docker
then
    echo "Installation failed: could not enable and start Docker."
    exit 1
fi

if ! docker info > /dev/null
then
    echo "Installation failed: Docker Engine is not responding."
    exit 1
fi

if ! docker compose version > /dev/null
then
    echo "Installation failed: Docker Compose is unavailable."
    exit 1
fi

# Load prepared images para offline ang startup
echo "Loading the prepared Docker images..."
for image_archive in images.tar prediction-image.tar
do
    if ! docker image load --input "$staging_directory/$image_archive"
    then
        echo "Installation failed: could not load $image_archive."
        exit 1
    fi
done

# Keep the source archive para sa next rebuild
if ! rm -- "$staging_directory/images.tar" "$staging_directory/prediction-image.tar"
then
    echo "Installation failed: could not remove the temporary image archive."
    exit 1
fi

# Copy app files and keep settings private para safe ang credentials
if ! chmod -R u=rwX,go=rX "$staging_directory" ||
   ! install -d -o root -g root -m 755 -- "$app_directory" ||
   ! cp -a -- "$staging_directory/." "$app_directory/"
then
    echo "Installation failed: could not copy the application files."
    exit 1
fi

if [ ! -f "$app_directory/.env" ]
then
    if ! install -o root -g root -m 600 -- "$config_file" "$app_directory/.env"
    then
        echo "Installation failed: could not copy the private configuration."
        exit 1
    fi
fi

if ! chmod 600 -- "$app_directory/.env"
then
    echo "Installation failed: could not protect the configuration file."
    exit 1
fi

# Match evidence ownership para the worker can write there
if ! install -d -o 10001 -g 10001 -m 700 -- "$app_directory/bootstrap-snapshots"
then
    echo "Installation failed: could not prepare the private bootstrap evidence directory."
    exit 1
fi

# Reuse Compose settings habang passing through the function arguments
# Keep course volumes sa dedicated Compose project
compose()
{
    # Clear inherited settings para Compose reads the private configuration
    # Keep only the environment values para sa local Docker
    env -i PATH="$PATH" HOME="$HOME" DOCKER_HOST=unix:///var/run/docker.sock \
    WORKER_IMAGE_TAG=local \
    BOOTSTRAP_RUN_MANIFEST=/app/workers/bootstrap-snapshots/bootstrap-readiness.json \
    docker compose --project-name quakestrikeph-sam --env-file "$app_directory/.env" \
        -f "$app_directory/infrastructure/compose.yml" \
        -f "$app_directory/infrastructure/compose.backend.yml" \
        -f "$app_directory/infrastructure/compose.local.yml" \
        -f "$app_directory/infrastructure/compose.release.yml" \
        -f "$app_directory/infrastructure/compose.checkoff.yml" "$@"
}

if ! compose config --quiet
then
    echo "Installation failed: the Compose configuration is invalid."
    exit 1
fi

# Check required images muna before stopping services
if ! required_images=$(compose --profile init --profile prediction config --images)
then
    echo "Installation failed: could not read the required image names."
    exit 1
fi

for image in $required_images
do
    if ! docker image inspect "$image" > /dev/null
    then
        echo "Installation failed: the prepared image archives do not provide $image."
        exit 1
    fi
done

# Stop workers and web services muna before database setup
if ! compose --profile prediction --profile beat --profile alerts stop \
    beat data-ingestor dispatcher prediction-worker alert-worker alert-reconciliation backend-api bulletin
then
    echo "Installation failed: could not stop application services before database setup."
    exit 1
fi

# Wait for healthy PostgreSQL and Redis services muna
echo "Starting PostgreSQL and Redis..."
if ! compose up -d --no-build --pull never --wait --wait-timeout 120 postgres redis
then
    echo "Installation failed: PostgreSQL or Redis did not become healthy."
    exit 1
fi

# Reuse application commands para sa database roles and migrations
if ! compose exec -T postgres sh /opt/quakestrike/provision-roles.sh create
then
    echo "Installation failed: could not create the migration and worker database users."
    exit 1
fi

if ! compose run --rm --no-deps --pull never local-init quakestrike migrate
then
    echo "Installation failed: could not apply the database migrations."
    exit 1
fi

# Grant worker access pagkatapos ng migrations
if ! compose exec -T postgres sh /opt/quakestrike/provision-roles.sh grant-worker
then
    echo "Installation failed: could not grant the worker database permissions."
    exit 1
fi

if ! compose run --rm --no-deps --pull never local-init quakestrike register-model-release ||
   ! compose run --rm --no-deps --pull never local-init quakestrike verify-model-release
then
    echo "Installation failed: could not register and verify the packaged model release."
    exit 1
fi

if ! compose exec -T postgres sh /opt/quakestrike/provision-roles.sh create-backend
then
    echo "Installation failed: could not create the Backend database user."
    exit 1
fi

echo "Starting the Backend and Bulletin..."
if ! compose up -d --no-build --pull never --wait --wait-timeout 180 postgres redis backend-api bulletin
then
    echo "Installation failed: the web application did not become healthy."
    exit 1
fi

# Check HTTP responses gamit ang Node inside both web containers
if ! compose exec -T backend-api node -e "fetch('http://127.0.0.1:3000/healthz').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))" ||
   ! compose exec -T bulletin node -e "fetch('http://127.0.0.1:4321/').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))"
then
    echo "Installation failed: the Backend or Bulletin HTTP check failed."
    exit 1
fi

# Keep existing records and evidence kapag reinstalling
if [ -f "$app_directory/bootstrap-snapshots/bootstrap-readiness.json" ]
then
    if ! compose run --rm --no-deps --pull never release-init quakestrike startup-check ||
       ! compose --profile prediction up -d --no-deps --no-build --pull never --wait --wait-timeout 180 dispatcher prediction-worker
    then
        echo "Installation failed: existing bootstrap evidence or prediction services are not ready."
        exit 1
    fi
fi

echo "Installation successful. Application directory: $app_directory"
echo "Open http://127.0.0.1:4321 on the machine hosting this demo."
echo "Run quakestrikeph-seed.sh --directory '$app_directory' to load and verify the demo forecast."
exit 0
