#!/bin/bash

# Run all deployment scripts in order on a blank server and confirm the app works.
# Authors: Armenta, Buergo, Candelaria, Pispis
# Usage: sudo bash quakestrikeph-rebuild.sh --archive FILE --backup FILE [--config FILE] [--directory PATH]
# AI assistance: Antigravity and ChatGPT helped simplify and review this script.

app_directory="/srv/quakestrikeph"
app_archive=""
backup_file=""
config_file="/root/demo.env"

fail()
{
    echo "Full rebuild failed: $*" >&2
    exit 1
}

while [ "$#" -gt 0 ]
do
    if [ "$1" = "--help" ]
    then
        echo "Usage: sudo bash quakestrikeph-rebuild.sh --archive FILE --backup FILE [--config FILE] [--directory PATH]"
        echo "Run accounts, config, install, final permissions, database restore, and HTTP checks."
        echo ""
        echo "Options:"
        echo "  --archive FILE    Prepared offline application archive (.tar.gz)."
        echo "  --backup FILE     Compressed PostgreSQL backup (.sql.gz) with test/earthquake data."
        echo "  --config FILE     Private .env file to create or reuse. Default: /root/demo.env"
        echo "  --directory PATH  Application folder under /srv. Default: /srv/quakestrikeph"
        echo "  --help            Show this help message and exit."
        echo ""
        echo "Example:"
        echo "  sudo bash quakestrikeph-rebuild.sh --archive /root/quakestrikeph-app.tar.gz --backup /root/quakestrikeph-db-backup.sql.gz"
        exit 0

    elif [ "$1" = "--archive" ] || [ "$1" = "--backup" ] || [ "$1" = "--config" ] || [ "$1" = "--directory" ]
    then
        if [ "$#" -lt 2 ] || [ -z "$2" ]
        then
            fail "$1 requires a value."
        fi
        if [ "$1" = "--archive" ]
        then
            app_archive="$2"
        elif [ "$1" = "--backup" ]
        then
            backup_file="$2"
        elif [ "$1" = "--config" ]
        then
            config_file="$2"
        else
            app_directory="${2%/}"
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

for required_command in bash dirname tar gzip grep df
do
    if ! command -v "$required_command" > /dev/null
    then
        fail "$required_command is required."
    fi
done

if [ ! -r "$app_archive" ]
then
    fail "use --archive to supply a readable application archive."
fi

if [ ! -r "$backup_file" ]
then
    fail "use --backup to supply a readable .sql.gz database backup."
fi

script_directory=$(dirname "$0")
for script in quakestrikeph-accounts.sh quakestrikeph-config.sh quakestrikeph-install.sh quakestrikeph-restore.sh
do
    if [ ! -r "$script_directory/$script" ]
    then
        fail "missing script beside rebuild: $script"
    fi
done

# Show available disk space before extraction and Docker image loading.
echo "Disk space before rebuild (/tmp, /srv, /var/lib):"
df -h /tmp /srv /var/lib || fail "could not check disk space."

# Verify both compressed archives are intact and contain expected structure.
if ! tar -tzf "$app_archive" | grep -Eq '^(\./)?infrastructure/compose\.yml$' > /dev/null
then
    fail "$app_archive is corrupted or missing infrastructure/compose.yml."
fi

if ! gzip -t "$backup_file"
then
    fail "$backup_file is corrupted or not a valid gzip archive."
fi

echo "Step 1/6: prepare service account and directory..."
bash "$script_directory/quakestrikeph-accounts.sh" --directory "$app_directory" \
    || fail "initial accounts setup failed."

echo "Step 2/6: prepare or reuse private configuration..."
bash "$script_directory/quakestrikeph-config.sh" --output "$config_file" --directory "$app_directory" \
    || fail "configuration setup failed."

echo "Step 3/6: install Docker offline and deploy QuakeStrikePH..."
bash "$script_directory/quakestrikeph-install.sh" --archive "$app_archive" --config "$config_file" --directory "$app_directory" \
    || fail "installation failed."

echo "Step 4/6: apply final least-privilege permissions..."
bash "$script_directory/quakestrikeph-accounts.sh" --directory "$app_directory" \
    || fail "final permissions setup failed."

echo "Step 5/6: restore earthquake and forecast data..."
bash "$script_directory/quakestrikeph-restore.sh" --backup "$backup_file" --directory "$app_directory" \
    || fail "database restore failed."

compose()
{
    WORKER_IMAGE_TAG=local \
    docker compose --project-name quakestrikeph-sam --env-file "$app_directory/.env" \
        -f "$app_directory/infrastructure/compose.yml" \
        -f "$app_directory/infrastructure/compose.backend.yml" \
        -f "$app_directory/infrastructure/compose.local.yml" \
        -f "$app_directory/infrastructure/compose.checkoff.yml" "$@"
}

echo "Step 6/6: verify Backend and Bulletin HTTP responses..."
compose exec -T backend-api node -e "fetch('http://127.0.0.1:3000/healthz').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))" \
    || fail "Backend HTTP check failed."
compose exec -T bulletin node -e "fetch('http://127.0.0.1:4321/').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))" \
    || fail "Bulletin HTTP check failed."

echo "Full rebuild successful: QuakeStrikePH is running with restored data."
echo "Open http://127.0.0.1:4321 to verify the website."
exit 0
