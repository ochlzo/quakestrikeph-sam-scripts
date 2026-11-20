#!/bin/bash
# AI-assisted checks on temporary test credentials only. No live file is changed.
set -eu
repository=$(cd -- "$(dirname -- "$0")/.." && pwd)
script="$repository/quakestrikeph-config.sh"
[ "$EUID" -eq 0 ] || { echo 'Run as root in the demo environment.'; exit 1; }
umask 077
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT

bash "$script" --directory "$work/app" --output "$work/demo.env"
[ "$(stat -c '%a %u %h' "$work/demo.env")" = '600 0 1' ]
python3 - "$work/demo.env" <<'PY'
import re
import sys
from pathlib import Path

data = Path(sys.argv[1]).read_bytes()
assert b'\r' not in data
settings = dict(line.split('=', 1) for line in data.decode().splitlines() if line and not line.startswith('#'))
passwords = [settings[key] for key in ('POSTGRES_PASSWORD', 'MIGRATION_DB_PASSWORD', 'WORKER_DB_PASSWORD', 'BACKEND_DB_PASSWORD')]
assert len(set(passwords)) == 4
assert all(re.fullmatch('[0-9a-f]{64}', value) for value in passwords)
for key, secret, role, scheme in (
    ('MIGRATION_DATABASE_URL', 'MIGRATION_DB_PASSWORD', 'quakestrike_migration', 'postgresql+psycopg'),
    ('DATABASE_URL', 'WORKER_DB_PASSWORD', 'quakestrike_worker', 'postgresql+psycopg'),
    ('BACKEND_DATABASE_URL', 'BACKEND_DB_PASSWORD', 'quakestrike_backend', 'postgresql'),
):
    assert settings[key] == f'{scheme}://{role}:{settings[secret]}@postgres:5432/quakestrike'
print('PASS: distinct passwords, matching URLs, private permissions, LF format.')
PY

# Preserve every byte, including optional values and comments, on reruns.
printf '\n# Preserve this operator note.\nPUBLIC_CLERK_PUBLISHABLE_KEY=\n' >> "$work/demo.env"
cp "$work/demo.env" "$work/original"
bash "$script" --directory "$work/app" --output "$work/demo.env"
cmp -s "$work/original" "$work/demo.env"
chmod 400 "$work/demo.env"
bash "$script" --directory "$work/app" --output "$work/demo.env"
[ "$(stat -c '%a' "$work/demo.env")" = 400 ]
cmp -s "$work/original" "$work/demo.env"

# A lost input file is recovered from installed settings, never regenerated.
mkdir "$work/app"
cp "$work/demo.env" "$work/app/.env"
bash "$script" --directory "$work/app" --output "$work/recovered.env"
cmp -s "$work/app/.env" "$work/recovered.env"
bash "$script" --directory "$work/app" --output "$work/recovered.env"
cmp -s "$work/original" "$work/recovered.env"

expect_unchanged_failure()
{
    cp "$1" "$work/before-failure"
    if bash "$script" --directory "$2" --output "$1" > "$work/error" 2>&1
    then
        echo 'FAIL: invalid or conflicting existing configuration accepted.'
        exit 1
    fi
    cmp -s "$work/before-failure" "$1"
}

printf 'not a configuration\n' > "$work/invalid.env"
expect_unchanged_failure "$work/invalid.env" "$work/empty-app"
cp "$work/original" "$work/duplicate.env"
printf '\nMODEL_RELEASE_ID=duplicate\n' >> "$work/duplicate.env"
expect_unchanged_failure "$work/duplicate.env" "$work/empty-app"
bash "$script" --directory "$work/other-app" --output "$work/other.env"
expect_unchanged_failure "$work/other.env" "$work/app"
cmp -s "$work/original" "$work/app/.env"
ln -s "$work/demo.env" "$work/link.env"
expect_unchanged_failure "$work/link.env" "$work/empty-app"

mkdir -p "$work/lost-config-app/infrastructure"
touch "$work/lost-config-app/infrastructure/compose.checkoff.yml"
if bash "$script" --directory "$work/lost-config-app" --output "$work/replacement.env" > "$work/error" 2>&1
then
    echo 'FAIL: generated replacement credentials for an installation missing its .env.'
    exit 1
fi
test ! -e "$work/replacement.env"

# Failure to generate randomness must leave no published or temporary config.
mkdir "$work/bin"
printf '#!/bin/bash\nexit 42\n' > "$work/bin/openssl"
chmod 700 "$work/bin/openssl"
if PATH="$work/bin:$PATH" bash "$script" --directory "$work/empty-app" --output "$work/failed.env" > "$work/error" 2>&1
then
    echo 'FAIL: random generator failure ignored.'
    exit 1
fi
test ! -e "$work/failed.env"
test -z "$(find "$work" -name '.quakestrikeph-config.*' -print -quit)"

# Optional real Compose parsing only: never start services with these test passwords.
app=/srv/quakestrikeph
if command -v docker > /dev/null && [ -f "$app/infrastructure/compose.checkoff.yml" ]
then
    WORKER_IMAGE_TAG=local docker compose --env-file "$work/demo.env" \
        -f "$app/infrastructure/compose.yml" \
        -f "$app/infrastructure/compose.backend.yml" \
        -f "$app/infrastructure/compose.local.yml" \
        -f "$app/infrastructure/compose.release.yml" \
        -f "$app/infrastructure/compose.checkoff.yml" --profile prediction config --quiet
    echo 'PASS: generated configuration accepted by real Compose (no services started).'
fi
echo 'PASS: unchanged reruns, installed-config reuse, conflict/invalid/link rejection, random-failure cleanup.'

# In the established demo, prove both real files stay byte-identical. Only hashes
# are held in shell variables; neither hashes nor secret values are printed.
if [ -f /root/demo.env ] && [ -f /srv/quakestrikeph/.env ]
then
    before=$(sha256sum /root/demo.env /srv/quakestrikeph/.env)
    bash "$script"
    bash "$script"
    after=$(sha256sum /root/demo.env /srv/quakestrikeph/.env)
    [ "$before" = "$after" ]
    echo 'PASS: existing demo.env and installed .env are byte-identical after two runs.'
fi
