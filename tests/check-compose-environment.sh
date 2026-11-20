#!/bin/bash
# Authors: Armenta, Buergo, Candelaria, Pispis
# AI-assisted regression test using temporary credentials and read-only Compose
# parsing. No installer, seed, rebuild, or Docker service operation is executed.
# Usage: sudo bash tests/check-compose-environment.sh [APPLICATION_SOURCE]
set -eu
repository=$(cd -- "$(dirname -- "$0")/.." && pwd)
application_source="${1:-$repository/../quakestrikeph}"
[ "$EUID" -eq 0 ] || { echo 'Run as root to generate temporary private test configuration.'; exit 1; }
for command_name in docker python3 sed
do
    command -v "$command_name" > /dev/null
done
umask 077
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
app_directory="$work/app"
mkdir -p "$app_directory/infrastructure"
for file in compose.yml compose.backend.yml compose.local.yml compose.release.yml
do
    cp "$application_source/infrastructure/$file" "$app_directory/infrastructure/$file"
done
bash "$repository/quakestrikeph-config.sh" --output "$work/demo.env" --directory "$app_directory" > /dev/null
cp "$work/demo.env" "$app_directory/.env"
printf 'services: {}\n' > "$app_directory/infrastructure/compose.checkoff.yml"

# Deliberately conflict with every database password and URL, including variables
# that could redirect the deployment. Only fixture values are used here.
export POSTGRES_PASSWORD=shell-override MIGRATION_DB_PASSWORD=shell-override
export WORKER_DB_PASSWORD=shell-override BACKEND_DB_PASSWORD=shell-override
export POSTGRES_USER=shell-override POSTGRES_DB=shell-override
export MIGRATION_DATABASE_URL=postgresql://shell-override
export DATABASE_URL=postgresql://shell-override BACKEND_DATABASE_URL=postgresql://shell-override
export ACCOUNT_REDIS_URL=redis://shell-override REDIS_URL=redis://shell-override
export MODEL_RELEASE_ID=shell-override MODEL_ARTIFACT_HOST_DIRECTORY=/shell-override
export DOCKER_HOST=tcp://example.invalid:2376 DOCKER_CONTEXT=unrelated
export WORKER_IMAGE_TAG=shell-override BOOTSTRAP_RUN_MANIFEST=/shell-override

for script in quakestrikeph-install.sh quakestrikeph-seed.sh quakestrikeph-rebuild.sh
do
    # Load only the real compose() helper, never the script's lifecycle commands.
    sed -n '/^compose()/,/^}/p' "$repository/$script" > "$work/compose-function.sh"
    grep -q '^compose()' "$work/compose-function.sh"
    source "$work/compose-function.sh"
    for attempt in 1 2
    do
        compose --profile init --profile prediction config --format json > "$work/resolved.json"
        python3 - "$work/demo.env" "$work/resolved.json" <<'PY'
import json
import sys
from pathlib import Path

settings = dict(line.split('=', 1) for line in Path(sys.argv[1]).read_text().splitlines()
                if line and not line.startswith('#'))
services = json.loads(Path(sys.argv[2]).read_text())['services']
for key in ('POSTGRES_PASSWORD', 'MIGRATION_DB_PASSWORD', 'WORKER_DB_PASSWORD',
            'BACKEND_DB_PASSWORD', 'POSTGRES_USER', 'POSTGRES_DB'):
    assert services['postgres']['environment'][key] == settings[key], key
assert services['backend-api']['environment']['DATABASE_URL'] == settings['BACKEND_DATABASE_URL']
assert services['backend-api']['environment']['ACCOUNT_REDIS_URL'] == settings['ACCOUNT_REDIS_URL']
assert services['local-init']['environment']['DATABASE_URL'] == settings['MIGRATION_DATABASE_URL']
for service in ('dispatcher', 'prediction-worker'):
    for key in ('DATABASE_URL', 'REDIS_URL', 'MODEL_RELEASE_ID'):
        assert services[service]['environment'][key] == settings[key], (service, key)
    assert services[service]['environment']['BOOTSTRAP_RUN_MANIFEST'] == settings['BOOTSTRAP_RUN_MANIFEST']
assert services['prediction-worker']['image'] == 'quakestrike-prediction:local'
PY
        cmp -s "$work/demo.env" "$app_directory/.env"
    done
    echo "PASS: $script ignores exported application overrides; temporary credential files unchanged."
done
echo 'Real Compose configuration parsing only; no Docker services or database were changed.'
