#!/bin/bash
# AI-assisted checks: real Bash parsing and input validation; package/service
# commands are substitutes in the image-load failure test. No real installation.
set -euo pipefail
repository=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT

for script in quakestrikeph-install.sh quakestrikeph-seed.sh quakestrikeph-accounts.sh quakestrikeph-config.sh quakestrikeph-uninstall.sh quakestrikeph-rebuild.sh
do
    bash -n "$repository/$script"
    # Save key help lines para sa standards checks
    bash "$repository/$script" --help |
        grep -E '^Usage:|^[[:space:]]*Example|--help' > "$work/help"
    grep -q '^Usage:' "$work/help"
    grep -q '^[[:space:]]*Example' "$work/help"
    grep -Fq -- '--help' "$work/help"
    for option in --unknown --directory
    do
        if bash "$repository/$script" "$option" > "$work/error" 2>&1
        then
            echo "FAIL: $script accepted $option"
            exit 1
        fi
        grep -q 'Error:' "$work/error"
    done
done

if [ "$EUID" -ne 0 ] || [ ! -d /run/systemd/system ]
then
    echo 'Syntax/help/argument checks passed; root/systemd required for preflight checks.'
    exit 0
fi

app=$(mktemp -d /srv/quakestrikeph-install-test.XXXXXX)
trap 'rm -rf -- "$work" "$app"' EXIT

mkdir -p "$work/bundle/infrastructure" "$work/bundle/database/initialization" \
    "$work/bundle/apps/quakestrikeph-bulletin" "$work/bundle/model-artifacts/seis-1.0.1" \
    "$work/bundle/workers/tests/fixtures/bootstrap" "$work/bin"
for file in infrastructure/compose.yml infrastructure/compose.backend.yml \
    infrastructure/compose.local.yml infrastructure/compose.release.yml \
    database/initialization/provision-roles.sh apps/quakestrikeph-bulletin/package.json \
    model-artifacts/seis-1.0.1/manifest.json workers/tests/fixtures/bootstrap/historical_snapshot.json images.tar
do
    touch "$work/bundle/$file"
done
cat > "$work/demo.env" <<'ENV'
POSTGRES_PASSWORD=test
MIGRATION_DB_PASSWORD=test
WORKER_DB_PASSWORD=test
BACKEND_DB_PASSWORD=test
MODEL_RELEASE_ID=test
BACKEND_IMAGE_TAG=local
PHIVOLCS_CATALOG_URL=https://example.invalid
BOOTSTRAP_REQUIRED_AVAILABLE_THROUGH=2026-09-01T00:00:00+08:00
MIGRATION_DATABASE_URL=postgresql://test@postgres:5432/quakestrike
DATABASE_URL=postgresql://test@postgres:5432/quakestrike
BACKEND_DATABASE_URL=postgresql://test@postgres:5432/quakestrike
MODEL_ARTIFACT_HOST_DIRECTORY=../model-artifacts
REDIS_URL=redis://redis:6379/0
ENV
chmod 600 "$work/demo.env"

# Every simulated mutation is recorded. Preflight must reject missing input first.
cat > "$work/bin/apt-get" <<'SH'
#!/bin/bash
echo package >> "$TEST_CALLS"
SH
cat > "$work/bin/systemctl" <<'SH'
#!/bin/bash
echo service >> "$TEST_CALLS"
SH
cat > "$work/bin/docker" <<'SH'
#!/bin/bash
echo "docker $*" >> "$TEST_CALLS"
if [[ "$*" == *prediction-image.tar* ]]; then exit 42; fi
SH
chmod +x "$work/bin/"*
export TEST_CALLS="$work/calls"
export PATH="$work/bin:$PATH"
tar -czf "$work/app.tar.gz" -C "$work/bundle" .

expect_path_failure()
{
    local target="$1" message="$2"
    if bash "$repository/quakestrikeph-install.sh" --archive "$work/app.tar.gz" \
        --config "$work/demo.env" --directory "$target" > "$work/error" 2>&1
    then
        echo "FAIL: unsafe destination accepted: $target"
        exit 1
    fi
    grep -q "$message" "$work/error"
    test ! -e "$TEST_CALLS"
}
for target in / /etc /srv "$app/.." "$app/child" "$work/installed"
do
    expect_path_failure "$target" 'dedicated /srv/NAME\|dot segments'
done
expect_path_failure "$app" 'missing prediction-image.tar'
printf 'unrelated file\n' > "$app/keep"
expect_path_failure "$app" 'nonempty directory'
test "$(cat "$app/keep")" = 'unrelated file'
rm -- "$app/keep"
# Use only the harness-owned path for file/symlink fixtures.
rmdir "$app"
expect_path_failure "$app" 'missing prediction-image.tar'
ln -s "$work" "$app"
expect_path_failure "$app" 'symlink paths'
rm -- "$app"
touch "$app"
expect_path_failure "$app" 'not a directory'
rm -- "$app"
mkdir "$app"
mkdir -p "$app/infrastructure" "$app/apps/quakestrikeph-bulletin"
touch "$app/infrastructure/compose.checkoff.yml" "$app/apps/quakestrikeph-bulletin/package.json"
expect_path_failure "$app" 'missing its .env'
cp "$work/demo.env" "$app/.env"
ln -s "$work" "$app/linked"
expect_path_failure "$app" 'linked file'
rm -- "$app/linked"
ln "$work/demo.env" "$app/linked"
expect_path_failure "$app" 'linked file'
rm -- "$app/linked"
cat > "$work/bin/findmnt" <<'SH'
#!/bin/bash
echo "$TEST_MOUNT"
SH
chmod +x "$work/bin/findmnt"
export TEST_MOUNT="$app/nested-mount"
expect_path_failure "$app" 'unmount'
rm -- "$work/bin/findmnt"
# The recognized installation and matching credentials reach archive validation.
if bash "$repository/quakestrikeph-install.sh" --archive "$work/app.tar.gz" \
    --config "$work/demo.env" --directory "$app" > "$work/error" 2>&1
then
    echo 'FAIL: missing prediction archive accepted'
    exit 1
fi
grep -q 'missing prediction-image.tar' "$work/error"
test ! -e "$TEST_CALLS"

touch "$work/bundle/prediction-image.tar"
tar -czf "$work/app.tar.gz" -C "$work/bundle" .
if bash "$repository/quakestrikeph-install.sh" --archive "$work/app.tar.gz" \
    --config "$work/demo.env" --directory "$app" > "$work/error" 2>&1
then
    echo 'FAIL: failed prediction image load accepted'
    exit 1
fi
grep -q 'could not load prediction-image.tar' "$work/error"
cmp -s "$work/demo.env" "$app/.env"
echo 'PASS: syntax, help, arguments, unsafe destination guards, preflight ordering, image-load failure propagation.'
