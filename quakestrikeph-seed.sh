#!/bin/bash

# Load sanitized test data and verify a saved forecast
# Authors: Armenta, Buergo, Candelaria, Pispis
# Usage: sudo bash quakestrikeph-seed.sh --directory /srv/quakestrikeph
# Run after installation and final permissions
# AI assistance: ChatGPT helped implement and test this script.
# Adapted from QuakeStrikePH docs/operations/local-runtime.md, sections 6-7
# and the prediction operations query. The group must understand every step.

app_directory="/srv/quakestrikeph"

while [ "$#" -gt 0 ]
do
    if [ "$1" = "--help" ]
    then
        echo "Usage: sudo bash quakestrikeph-seed.sh [--directory PATH]"
        echo "Import the packaged historical test fixture and verify its forecast."
        echo "Run quakestrikeph-install.sh first. Default directory: /srv/quakestrikeph"
        echo "Repeated runs reuse the same bootstrap evidence and existing database records."
        echo "This script starts Dispatcher and Prediction Worker, not live ingestion or alerts."
        echo "Example: sudo bash quakestrikeph-seed.sh --directory /srv/quakestrikeph"
        exit 0
    elif [ "$1" = "--directory" ]
    then
        if [ "$#" -lt 2 ] || [ -z "$2" ] || [[ "$2" == --* ]]
        then
            echo "Error: --directory requires a value."
            exit 1
        fi
        app_directory="$2"
        shift 2
    else
        echo "Error: unknown option '$1'. Use --help."
        exit 1
    fi
done

if [ "$EUID" -ne 0 ]
then
    echo "Run this script with root privileges."
    exit 1
fi

for required_command in docker realpath sha256sum stat sleep env
do
    if ! command -v "$required_command" > /dev/null
    then
        echo "Seed failed: $required_command is required."
        exit 1
    fi
done

if ! app_directory=$(realpath -e -- "$app_directory")
then
    echo "Seed failed: the installation directory does not exist."
    exit 1
fi

for required_file in .env infrastructure/compose.yml infrastructure/compose.backend.yml \
    infrastructure/compose.local.yml infrastructure/compose.release.yml infrastructure/compose.checkoff.yml \
    workers/tests/fixtures/bootstrap/historical_snapshot.json
do
    if [ ! -r "$app_directory/$required_file" ]
    then
        echo "Seed failed: missing $required_file. Run the updated installer first."
        exit 1
    fi
done

if [ "$(stat -c '%a' -- "$app_directory/.env")" != "600" ]
then
    echo "Seed failed: the installed .env must have permissions 600."
    exit 1
fi

# Use only the reviewed fixture para sa demo
snapshot_file="$app_directory/workers/tests/fixtures/bootstrap/historical_snapshot.json"
if ! snapshot_hash=$(sha256sum -- "$snapshot_file") ||
   [ "${snapshot_hash%% *}" != "9fdf3c0e0b0abd8dfa7148539c77ac369f93d679cf4488befae160dc86db5f19" ]
then
    echo "Seed failed: the historical test fixture does not match the reviewed demo."
    exit 1
fi

compose()
{
    # Clear inherited settings para Compose uses the private configuration
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

# Check the prediction setup muna before importing data
if ! compose --profile prediction config --quiet
then
    echo "Seed failed: the Compose configuration is invalid."
    exit 1
fi

# Reuse saved import evidence kapag matching ang fixture
# Expect four rejected rows sa test fixture
echo "Importing the sanitized demo fixture (four rejected rows are expected)..."
# Mount the fixture read only para safe ang test data
if ! compose run --rm --no-deps --pull never \
    --volume "$snapshot_file:/demo/input.json:ro" \
    release-init quakestrike bootstrap --snapshot /demo/input.json \
    --run-manifest /app/workers/bootstrap-snapshots/bootstrap-readiness.json
then
    echo "Seed failed: bootstrap did not complete. Preserve the evidence folder for diagnosis."
    exit 1
fi

# Check database and model readiness muna before starting the workers
if ! compose run --rm --no-deps --pull never release-init quakestrike startup-check
then
    echo "Seed failed: startup readiness did not pass."
    exit 1
fi

if ! compose --profile prediction up -d --no-deps --no-build --pull never \
    --wait --wait-timeout 180 dispatcher prediction-worker
then
    echo "Seed failed: Dispatcher or Prediction Worker did not become healthy."
    exit 1
fi

# Verify the saved forecast sa database after the workers start
# Match the forecast sa demo event with a successful job
forecast_query="
    SELECT COUNT(*)
    FROM forecasts f
    JOIN prediction_jobs p ON p.job_id = f.job_id
    JOIN earthquake_event_revisions r ON r.event_revision_id = p.event_revision_id
    WHERE p.status = 'succeeded'
      AND r.location_description = 'Sanitized prediction anchor';
"
# Poll PostgreSQL para may time for the forecast job to finish
echo "Waiting up to five minutes for the demo forecast..."
for ((attempt = 0; attempt < 60; attempt++))
do
    if ! forecast_count=$(compose exec -T postgres psql -U quakestrike -d quakestrike \
        -v ON_ERROR_STOP=1 -Atc "$forecast_query")
    then
        echo "Seed failed: could not query the saved forecast."
        exit 1
    fi
    if [[ "$forecast_count" =~ ^[0-9]+$ ]] && [ "$forecast_count" -gt 0 ]
    then
        echo "Seed successful: the demo forecast is saved."
        echo "Open http://127.0.0.1:4321 and select Sanitized prediction anchor."
        exit 0
    fi
    sleep 5
done

echo "Seed failed: no completed demo forecast within five minutes."
echo "Inspect prediction-worker and dispatcher logs; do not delete database volumes."
exit 1
