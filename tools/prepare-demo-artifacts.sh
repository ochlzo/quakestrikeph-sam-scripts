#!/bin/bash

# Local helper to export the two offline demo prerequisites:
#   1. quakestrikeph-app.tar.gz       (tracked app source + images.tar, without workers)
#   2. quakestrikeph-db-backup.sql.gz (full schema + earthquake/model/forecast data only, no user data)
#
# Authors: Armenta, Buergo, Candelaria, Pispis
# Usage: bash tools/prepare-demo-artifacts.sh [--app-repo PATH] [--db-only] [--output-dir PATH] [--db-url URL | --compose-project NAME]
# AI assistance: Antigravity helped write this preparation helper.
# Note: This is a local preparation tool, not one of the six submitted Option 1C scripts.

app_repo=""
output_dir="./demo-artifacts"
db_url=""
compose_project=""
db_only=false

fail()
{
    echo "Prep failed: $*" >&2
    exit 1
}

while [ "$#" -gt 0 ]
do
    if [ "$1" = "--help" ]
    then
        echo "Usage: bash tools/prepare-demo-artifacts.sh [--app-repo PATH] [--db-only] [--output-dir PATH] [--db-url URL | --compose-project NAME]"
        echo "Build the two offline prerequisites for the Option 1C demo:"
        echo "  1. quakestrikeph-app.tar.gz"
        echo "  2. quakestrikeph-db-backup.sql.gz (excludes user/account/alert/session tables)"
        echo ""
        echo "Options:"
        echo "  --app-repo PATH         Path to a clean local QuakeStrikePH Git checkout (not needed with --db-only)."
        echo "  --db-only               Export only quakestrikeph-db-backup.sql.gz and skip building the app archive."
        echo "  --output-dir PATH       Folder where exported files will be saved. Default: ./demo-artifacts"
        echo "  --db-url URL            PostgreSQL connection URL to dump earthquake data from (uses local pg_dump)."
        echo "  --compose-project NAME  Running Docker Compose project name to run pg_dump inside its postgres container."
        echo "  --help                  Show this help message and exit."
        echo ""
        echo "Examples:"
        echo "  bash tools/prepare-demo-artifacts.sh --app-repo /path/to/quakestrikeph --output-dir ./demo-artifacts"
        echo "  bash tools/prepare-demo-artifacts.sh --db-only --compose-project quakestrikeph --output-dir ~/demo-artifacts"
        exit 0

    elif [ "$1" = "--db-only" ]
    then
        db_only=true
        shift

    elif [ "$1" = "--app-repo" ] || [ "$1" = "--output-dir" ] || [ "$1" = "--db-url" ] || [ "$1" = "--compose-project" ]
    then
        if [ "$#" -lt 2 ] || [ -z "$2" ]
        then
            fail "$1 requires a value."
        fi
        if [ "$1" = "--app-repo" ]
        then
            app_repo="$2"
        elif [ "$1" = "--output-dir" ]
        then
            output_dir="$2"
        elif [ "$1" = "--db-url" ]
        then
            db_url="$2"
        else
            compose_project="$2"
        fi
        shift 2

    else
        fail "unknown option '$1'. Use --help."
    fi
done

command -v gzip > /dev/null || fail "gzip is required."

if [ "$db_only" = true ]
then
    if [ -z "$db_url" ] && [ -z "$compose_project" ]
    then
        fail "--db-only requires --db-url or --compose-project."
    fi
else
    for required_command in git docker tar mktemp
    do
        if ! command -v "$required_command" > /dev/null
        then
            fail "$required_command is required."
        fi
    done

    if [ -z "$app_repo" ] || [ ! -d "$app_repo/.git" ]
    then
        fail "use --app-repo to point to your QuakeStrikePH Git checkout."
    fi
fi

mkdir -p "$output_dir" || fail "could not create $output_dir."
output_dir=$(cd "$output_dir" && pwd)

# 1. Build and package quakestrikeph-app.tar.gz (web + DB images only, no workers)
if [ "$db_only" != true ]
then
    echo "Building local Docker images from $app_repo..."
    (
        cd "$app_repo" || exit 1
        docker compose --env-file .env \
            -f infrastructure/compose.yml \
            -f infrastructure/compose.backend.yml \
            -f infrastructure/compose.local.yml \
            build backend-api bulletin || exit 1

        docker compose --env-file .env \
            -f infrastructure/compose.yml \
            pull postgres redis || exit 1
    ) || fail "could not build or pull Docker images."

    bundle_dir=$(mktemp -d) || fail "could not create temporary bundle directory."
    trap 'rm -rf -- "$bundle_dir"' EXIT

    echo "Exporting tracked source files..."
    git -C "$app_repo" archive --format=tar HEAD | tar -xf - -C "$bundle_dir" || fail "could not export Git archive."

    echo "Saving Docker images to images.tar..."
    docker image save --output "$bundle_dir/images.tar" \
        postgres:16.15-bookworm \
        redis:7.4.11-bookworm \
        quakestrike-backend:local \
        quakestrike-bulletin:local \
        || fail "could not save Docker images."

    app_archive="$output_dir/quakestrikeph-app.tar.gz"
    echo "Creating $app_archive..."
    tar -czf "$app_archive" -C "$bundle_dir" . || fail "could not create $app_archive."
    tar -tzf "$app_archive" > /dev/null || fail "created archive failed integrity check."
fi

# 2. Export full schema + earthquake/model/forecast data (excluding user/account/alert rows)
dump_flags=(
    --inserts
    --on-conflict-do-nothing
    --no-owner
    --no-privileges
    --exclude-table-data='*user*'
    --exclude-table-data='*account*'
    --exclude-table-data='*alert*'
    --exclude-table-data='*audit*'
    --exclude-table-data='*job_dispatch*'
    --exclude-table-data='*session*'
    --exclude-table-data='*token*'
    --exclude-table-data='*subscription*'
    --exclude-table-data='*notification*'
)

backup_file="$output_dir/quakestrikeph-db-backup.sql.gz"

if [ -n "$db_url" ]
then
    command -v pg_dump > /dev/null || fail "pg_dump is required when using --db-url."
    echo "Dumping sanitized earthquake data from --db-url..."
    pg_dump "${dump_flags[@]}" "$db_url" | gzip -c > "$backup_file" \
        || fail "pg_dump failed."
    gzip -t "$backup_file" || fail "backup archive failed gzip integrity check."
elif [ -n "$compose_project" ]
then
    echo "Dumping sanitized earthquake data from Compose project $compose_project..."
    docker compose --project-name "$compose_project" exec -T postgres \
        pg_dump -U quakestrike -d quakestrike "${dump_flags[@]}" | gzip -c > "$backup_file" \
        || fail "docker compose pg_dump failed."
    gzip -t "$backup_file" || fail "backup archive failed gzip integrity check."
else
    echo "Note: skipped database backup (pass --db-url or --compose-project to export quakestrikeph-db-backup.sql.gz)."
fi

echo "Done! Files saved in: $output_dir"
ls -lh "$output_dir"
exit 0
