#!/bin/bash

# Restore sanitized earthquake and forecast data from a compressed PostgreSQL backup.
# Authors: Armenta, Buergo, Candelaria, Pispis
# Usage: sudo bash quakestrikeph-restore.sh --backup FILE [--directory /srv/quakestrikeph]
# AI assistance: Antigravity helped write and review this script.

app_directory="/srv/quakestrikeph"
backup_file=""

fail()
{
    echo "Database restore failed: $*" >&2
    exit 1
}

while [ "$#" -gt 0 ]
do
    if [ "$1" = "--help" ]
    then
        echo "Usage: sudo bash quakestrikeph-restore.sh --backup FILE [--directory PATH]"
        echo "Verify a compressed .sql.gz backup and restore earthquake/forecast data into PostgreSQL."
        echo "Safe to run twice: skips restore if earthquake records already exist."
        echo ""
        echo "Options:"
        echo "  --backup FILE     Compressed SQL backup (.sql.gz) with test/earthquake data only."
        echo "  --directory PATH  Application folder. Default: /srv/quakestrikeph"
        echo "  --help            Show this help message and exit."
        echo ""
        echo "Example:"
        echo "  sudo bash quakestrikeph-restore.sh --backup /root/quakestrikeph-db-backup.sql.gz"
        exit 0

    elif [ "$1" = "--backup" ] || [ "$1" = "--directory" ]
    then
        if [ "$#" -lt 2 ] || [ -z "$2" ]
        then
            fail "$1 requires a value."
        fi
        if [ "$1" = "--backup" ]
        then
            backup_file="$2"
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

for required_command in docker gzip gunzip stat
do
    if ! command -v "$required_command" > /dev/null
    then
        fail "$required_command is required."
    fi
done

if [ ! -r "$backup_file" ]
then
    fail "use --backup to supply a readable .sql.gz backup file."
fi

# Check that the compressed backup archive is intact before touching PostgreSQL.
if ! gzip -t "$backup_file"
then
    fail "$backup_file is corrupted or not a valid gzip archive."
fi

if [ ! -d "$app_directory" ] || [ ! -r "$app_directory/.env" ]
then
    fail "application is not installed in $app_directory. Run quakestrikeph-install.sh first."
fi

if [ "$(stat -c '%a' "$app_directory/.env")" != "600" ]
then
    fail "installed .env must have permissions 600."
fi

compose()
{
    WORKER_IMAGE_TAG=local \
    docker compose --project-name quakestrikeph-sam --env-file "$app_directory/.env" \
        -f "$app_directory/infrastructure/compose.yml" \
        -f "$app_directory/infrastructure/compose.backend.yml" \
        -f "$app_directory/infrastructure/compose.local.yml" \
        -f "$app_directory/infrastructure/compose.checkoff.yml" "$@"
}

# Check existing row count so running this script twice stays safe.
existing_rows=$(compose exec -T postgres psql -U quakestrike -d quakestrike \
    -v ON_ERROR_STOP=1 -Atc "SELECT COUNT(*) FROM earthquake_event_revisions;") \
    || fail "could not query PostgreSQL. Make sure the database is running."

if [ "$existing_rows" -gt 0 ]
then
    echo "Database already contains $existing_rows earthquake records; keeping existing data."
    exit 0
fi

# Stream the decompressed SQL dump directly into PostgreSQL.
echo "Restoring earthquake and forecast data from $backup_file..."
if ! gunzip -c "$backup_file" | compose exec -T postgres psql -U quakestrike -d quakestrike -v ON_ERROR_STOP=1 > /dev/null
then
    fail "could not restore SQL backup into PostgreSQL."
fi

# Reapply database role grants so Backend and Worker roles can read restored tables.
compose exec -T postgres sh /opt/quakestrike/provision-roles.sh grant-worker \
    || fail "could not refresh worker database permissions."

restored_rows=$(compose exec -T postgres psql -U quakestrike -d quakestrike \
    -v ON_ERROR_STOP=1 -Atc "SELECT COUNT(*) FROM earthquake_event_revisions;") \
    || fail "could not verify restored record count."

if [ "$restored_rows" -le 0 ]
then
    fail "restore finished, but no earthquake records were found in the database."
fi

echo "Database restore successful: $restored_rows earthquake records loaded."
echo "Open http://127.0.0.1:4321 to view the restored data."
exit 0
