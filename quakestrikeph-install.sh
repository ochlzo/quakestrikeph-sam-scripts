#!/bin/bash

# Install Docker offline and deploy the QuakeStrikePH web application.
# Authors: Armenta, Buergo, Candelaria, Pispis
# Usage: sudo bash quakestrikeph-install.sh --archive FILE --config FILE [--directory PATH]
# AI assistance: Antigravity and ChatGPT helped simplify and review this script.
# Sources: QuakeStrikePH docs/operations/local-runtime.md; Docker Compose and apt-get manuals.

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
        echo "Install Docker from cached packages and deploy QuakeStrikePH offline."
        echo ""
        echo "Options:"
        echo "  --archive FILE    Prepared offline application archive (.tar.gz)."
        echo "  --config FILE     Private .env file with permissions 600 or 400."
        echo "  --directory PATH  Application folder under /srv. Default: /srv/quakestrikeph"
        echo "  --help            Show this help message and exit."
        echo ""
        echo "Example:"
        echo "  sudo bash quakestrikeph-install.sh --archive /root/quakestrikeph-app.tar.gz --config /root/demo.env"
        exit 0

    elif [ "$1" = "--directory" ] || [ "$1" = "--archive" ] || [ "$1" = "--config" ]
    then
        if [ "$#" -lt 2 ] || [ -z "$2" ]
        then
            fail "$1 requires a value."
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
        fail "unknown option '$1'. Use --help."
    fi
done

if [ "$EUID" -ne 0 ]
then
    fail "run this script with root privileges."
fi

for required_command in apt-get systemctl tar mktemp stat grep cp chmod install cmp
do
    if ! command -v "$required_command" > /dev/null
    then
        fail "$required_command is required."
    fi
done

if [ ! -d /run/systemd/system ]
then
    fail "start the server with systemd enabled."
fi

# Detect Ubuntu 24.04 or Debian 13 to pick the right cached Docker packages.
if ! source /etc/os-release
then
    fail "could not read /etc/os-release."
fi

if [ "$ID" = "ubuntu" ] && [ "$VERSION_ID" = "24.04" ]
then
    docker_packages=(docker.io docker-compose-v2)
elif [ "$ID" = "debian" ] && [ "$VERSION_ID" = "13" ]
then
    docker_packages=(docker.io docker-cli docker-compose)
else
    fail "use Ubuntu 24.04 or Debian 13."
fi

# Validate inputs before changing anything on the server.
if [ ! -r "$app_archive" ]
then
    fail "use --archive to supply a readable application archive."
fi

if [ ! -r "$config_file" ]
then
    fail "use --config to supply a readable configuration file."
fi

config_mode=$(stat -c '%a' "$config_file")
if [ "$config_mode" != "600" ] && [ "$config_mode" != "400" ]
then
    fail "give the private configuration file permissions 600 or 400."
fi

case "$app_directory" in
    /srv/*) ;;
    *) fail "choose a dedicated folder inside /srv (for example /srv/quakestrikeph)." ;;
esac

# Avoid overwriting different database passwords on a repeated install.
if [ -f "$app_directory/.env" ] && ! cmp -s "$config_file" "$app_directory/.env"
then
    fail "$app_directory already has a different .env. Use its original configuration."
fi

for setting in POSTGRES_PASSWORD MIGRATION_DB_PASSWORD WORKER_DB_PASSWORD BACKEND_DB_PASSWORD \
    MIGRATION_DATABASE_URL DATABASE_URL BACKEND_DATABASE_URL MODEL_RELEASE_ID \
    BACKEND_IMAGE_TAG PHIVOLCS_CATALOG_URL REDIS_URL MODEL_ARTIFACT_HOST_DIRECTORY
do
    if ! grep -Eq "^${setting}=.+" "$config_file"
    then
        fail "$setting is missing or empty in $config_file."
    fi
done

# Extract and verify the offline archive in a temporary folder.
staging_directory=$(mktemp -d /tmp/quakestrikeph-install.XXXXXX) || fail "could not create a temporary directory."
trap 'rm -rf -- "$staging_directory"' EXIT

if ! tar --extract --gzip --file "$app_archive" --directory "$staging_directory" --no-same-owner --no-same-permissions
then
    fail "could not extract $app_archive."
fi

for required_file in infrastructure/compose.yml infrastructure/compose.backend.yml \
    infrastructure/compose.local.yml database/initialization/provision-roles.sh \
    apps/quakestrikeph-bulletin/package.json images.tar
do
    if [ ! -f "$staging_directory/$required_file" ]
    then
        fail "the archive is missing $required_file at its root."
    fi
done

if [ -e "$staging_directory/.env" ]
then
    fail "keep .env outside the application archive."
fi

# Small Compose override so Bulletin restarts automatically like the other services.
cat > "$staging_directory/infrastructure/compose.checkoff.yml" <<'YAML'
services:
  bulletin:
    restart: unless-stopped
YAML

# Step 1: Install Docker from the local APT cache and start the daemon.
echo "Installing Docker from cached packages..."
apt-get --no-download install -y "${docker_packages[@]}" || fail "could not install Docker from cached packages."
systemctl enable --now docker || fail "could not enable and start Docker."
docker info > /dev/null || fail "Docker Engine is not responding."
docker compose version > /dev/null || fail "Docker Compose is unavailable."

# Step 2: Load the exported Docker images offline.
echo "Loading the prepared Docker images..."
docker image load --input "$staging_directory/images.tar" || fail "could not load images.tar."
rm -- "$staging_directory/images.tar" || fail "could not remove temporary images.tar."

# Step 3: Copy application files and private configuration to the target folder.
chmod -R u=rwX,go=rX "$staging_directory" || fail "could not set staging permissions."
install -d -o root -g root -m 755 "$app_directory" || fail "could not prepare $app_directory."
cp -a "$staging_directory/." "$app_directory/" || fail "could not copy application files."

if [ ! -f "$app_directory/.env" ]
then
    install -o root -g root -m 600 "$config_file" "$app_directory/.env" || fail "could not install .env."
fi
chmod 600 "$app_directory/.env" || fail "could not protect .env."

# Helper to run Docker Compose with the same project name and files.
compose()
{
    WORKER_IMAGE_TAG=local \
    docker compose --project-name quakestrikeph-sam --env-file "$app_directory/.env" \
        -f "$app_directory/infrastructure/compose.yml" \
        -f "$app_directory/infrastructure/compose.backend.yml" \
        -f "$app_directory/infrastructure/compose.local.yml" \
        -f "$app_directory/infrastructure/compose.checkoff.yml" "$@"
}

compose config --quiet || fail "the Compose configuration is invalid."

# Stop web services before repeating database setup (safe on first and repeat runs).
compose stop backend-api bulletin > /dev/null 2>&1 || true

# Step 4: Start PostgreSQL and Redis and create the base database roles.
echo "Starting PostgreSQL and Redis..."
compose up -d --no-build --pull never --wait --wait-timeout 120 postgres redis \
    || fail "PostgreSQL or Redis did not become healthy."

compose exec -T postgres sh /opt/quakestrike/provision-roles.sh create \
    || fail "could not create base database roles."

# Step 5: If the schema is already restored (repeat install), restart web services and verify HTTP.
# On a fresh install, quakestrikeph-restore.sh loads the schema/data and starts Backend + Bulletin.
schema_ready=$(compose exec -T postgres psql -U quakestrike -d quakestrike \
    -v ON_ERROR_STOP=1 -Atc "SELECT to_regclass('public.model_releases');") \
    || fail "could not inspect PostgreSQL schema state."

if [ -n "$schema_ready" ]
then
    compose exec -T postgres sh /opt/quakestrike/provision-roles.sh create-backend \
        || fail "could not refresh Backend database role."
    echo "Starting Backend and Bulletin..."
    compose up -d --no-build --pull never --wait --wait-timeout 180 postgres redis backend-api bulletin \
        || fail "the web application did not become healthy."
    compose exec -T backend-api node -e "fetch('http://127.0.0.1:3000/healthz').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))" \
        || fail "Backend HTTP check failed."
    compose exec -T bulletin node -e "fetch('http://127.0.0.1:4321/').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))" \
        || fail "Bulletin HTTP check failed."
    echo "Installation successful. Application directory: $app_directory"
    echo "Website is responding at http://127.0.0.1:4321"
else
    echo "Installation successful. Application directory: $app_directory"
    echo "PostgreSQL and Redis are healthy. Run quakestrikeph-restore.sh next to load data and start the website."
fi
exit 0
