#!/bin/bash

# This is the installation script for running the quakestrikeph system
# Authors: Armenta, Buergo, Candelaria, Pispis
# Usage: bash quakestrikeph-install.sh --help
# AI assistance: ChatGPT explained Bash syntax and completed this script
# using the group's existing style. The group must understand every line.
# Sources: QuakeStrikePH docs/operations/local-runtime.md, section 9;
# https://docs.docker.com/reference/cli/docker/compose/up/
# https://docs.docker.com/reference/cli/docker/compose/run/
# https://manpages.debian.org/trixie/apt/apt-get.8.en.html

app_directory="/srv/quakestrikeph"
app_archive=""
config_file=""

while [ "$#" -gt 0 ]
do
    if [ "$1" = "--help" ]
    then
        echo "Usage: sudo bash quakestrikeph-install.sh --archive FILE --config FILE [--directory PATH]"
        echo "Install the QuakeStrikePH local web application on Debian 13 with systemd."
        echo ""
        echo "Options:"
        echo "  --archive FILE    Prepared offline application archive (.tar.gz)."
        echo "  --config FILE     Private demo environment file with permissions 600 or 400."
        echo "  --directory PATH  Installation directory. Default: /srv/quakestrikeph"
        echo "  --help            Show this help message and exit."
        echo ""
        echo "Example:"
        echo "  sudo bash quakestrikeph-install.sh --archive ./quakestrikeph.tar.gz --config ./demo.env"
        echo ""
        echo "Prepare before the offline rebuild:"
        echo "  Cache Debian packages with apt-get install --download-only docker.io docker-cli docker-compose."
        echo "  Put the repository contents directly at the archive root, without a parent folder."
        echo "  Include the reviewed model-artifacts/ directory and images.tar in that archive."
        echo "  Create images.tar with docker image save from the same working checkout."
        echo "  Include PostgreSQL, Redis, quakestrike-workers:local, quakestrike-backend:local,"
        echo "  and the development-stage quakestrike-bulletin:local image used by compose.local.yml."
        echo "  Use a dedicated installation directory and your group's trusted archive."
        echo "  Keep .env outside the archive. Supply a separate test-only configuration file."
        echo ""
        echo "This installs Bulletin, Backend, PostgreSQL, and Redis and initializes their schema."
        echo "The database seed or restore script supplies demonstration earthquake records."
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
            app_directory="$2"
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

#check if may root access
if [ "$EUID" -ne 0 ]
then
    echo "Run this script with root privileges."
    exit 1
fi

#check the tools before changing the system
for required_command in apt-get systemctl realpath tar mktemp stat grep cp chmod install cmp
do
    if ! command -v "$required_command" > /dev/null
    then
        echo "Installation failed: $required_command is required."
        exit 1
    fi
done

if [ ! -d /run/systemd/system ]
then
    echo "Installation failed: start Debian with systemd enabled."
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

#convert the path to absolute path para goods if ket san nirun yung script
if ! app_directory=$(realpath -m -- "$app_directory")
then
    echo "Installation failed: could not resolve the directory path."
    exit 1
fi

if [ "$app_directory" = "/" ]
then
    echo "Installation failed: choose a dedicated application directory."
    exit 1
fi

#avoid changing database passwords during a repeated installation
if [ -f "$app_directory/.env" ] && ! cmp -s -- "$config_file" "$app_directory/.env"
then
    echo "Installation failed: this directory already has a different configuration."
    echo "Use its original configuration for a repeated installation."
    exit 1
fi

#keep credentials in the separate private file instead of sourcing it as Bash
for setting in POSTGRES_PASSWORD MIGRATION_DB_PASSWORD WORKER_DB_PASSWORD BACKEND_DB_PASSWORD MODEL_RELEASE_ID BACKEND_IMAGE_TAG PHIVOLCS_CATALOG_URL
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

#unpack and check the offline files before installing packages
if ! staging_directory=$(mktemp -d /tmp/quakestrikeph-install.XXXXXX)
then
    echo "Installation failed: could not create a temporary directory."
    exit 1
fi
trap 'rm -rf -- "$staging_directory"' EXIT

if ! tar --extract --gzip --file "$app_archive" --directory "$staging_directory" --no-same-owner --no-same-permissions
then
    echo "Installation failed: could not extract the application archive."
    exit 1
fi

for required_file in infrastructure/compose.yml infrastructure/compose.backend.yml \
    infrastructure/compose.local.yml database/initialization/provision-roles.sh \
    apps/quakestrikeph-bulletin/package.json model-artifacts/seis-1.0.1/manifest.json images.tar
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

#install the downloaded docker package
echo "Installing Docker from cached packages..."
if ! apt-get --no-download install -y docker.io docker-cli docker-compose
then
    echo "Installation failed: could not install Docker from cached packages."
    exit 1
fi

#start the docker immediately and enable it when Debian boots
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

#load the prepared images so Compose can start without downloading or building
echo "Loading the prepared Docker images..."
if ! docker image load --input "$staging_directory/images.tar"
then
    echo "Installation failed: could not load images.tar."
    exit 1
fi

#the source archive remains available for the next rebuild
if ! rm -- "$staging_directory/images.tar"
then
    echo "Installation failed: could not remove the temporary image archive."
    exit 1
fi

#copy root-owned application files with readable code and a private configuration
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

#reuse the same Compose options for every step; "$@" passes the function arguments
#the separate project name keeps this course demo's volumes together
compose()
{
    docker compose --project-name quakestrikeph-sam --env-file "$app_directory/.env" \
        -f "$app_directory/infrastructure/compose.yml" \
        -f "$app_directory/infrastructure/compose.backend.yml" \
        -f "$app_directory/infrastructure/compose.local.yml" "$@"
}

if ! compose config --quiet
then
    echo "Installation failed: the Compose configuration is invalid."
    exit 1
fi

if ! required_images=$(compose --profile init config --images)
then
    echo "Installation failed: could not read the required image names."
    exit 1
fi

for image in $required_images
do
    if ! docker image inspect "$image" > /dev/null
    then
        echo "Installation failed: images.tar does not provide $image."
        exit 1
    fi
done

#stop the web services before migrations when this installer runs again
if ! compose stop backend-api bulletin
then
    echo "Installation failed: could not stop the web services before database setup."
    exit 1
fi

echo "Starting PostgreSQL and Redis..."
if ! compose up -d --no-build --pull never --wait --wait-timeout 120 postgres redis
then
    echo "Installation failed: PostgreSQL or Redis did not become healthy."
    exit 1
fi

#reuse the application's role provisioning and migration commands
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

#check real HTTP responses using Node, which is already in both web images
if ! compose exec -T backend-api node -e "fetch('http://127.0.0.1:3000/healthz').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))" ||
   ! compose exec -T bulletin node -e "fetch('http://127.0.0.1:4321/').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))"
then
    echo "Installation failed: the Backend or Bulletin HTTP check failed."
    exit 1
fi

echo "Installation successful. Application directory: $app_directory"
echo "Open http://127.0.0.1:4321 on the machine hosting this demo."
echo "Use the database seed or restore script to load your test earthquake records."
exit 0
