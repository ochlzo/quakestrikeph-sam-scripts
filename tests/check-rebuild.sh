#!/bin/bash
# Authors: Armenta, Buergo, Candelaria, Pispis
# AI-assisted coordinator tests. Accounts, installation, seeding, and Docker are
# substitutes. Real configuration generation uses only private temporary fixtures.
# Usage: sudo bash tests/check-rebuild.sh
set -eu
repository=$(cd -- "$(dirname -- "$0")/.." && pwd)
[ "$EUID" -eq 0 ] || { echo 'Run as root for temporary /srv fixtures.'; exit 1; }
umask 077
work=$(mktemp -d)
app=$(mktemp -d /srv/quakestrikeph-rebuild-test.XXXXXX)
trap 'rm -rf -- "$work" "$app"' EXIT
mkdir "$work/toolkit" "$work/bin" "$work/bundle"
cp "$repository/quakestrikeph-rebuild.sh" "$work/toolkit/"
script="$work/toolkit/quakestrikeph-rebuild.sh"
export TEST_APP="$app" TEST_CONFIG="$work/demo config.env" TEST_ARCHIVE="$work/app archive.tar.gz"
export TEST_LOG="$work/actions" TEST_REAL_CONFIG="$repository/quakestrikeph-config.sh"
export TEST_FAIL_STAGE=0
printf 'test archive only\n' > "$work/bundle/fixture"
tar -czf "$TEST_ARCHIVE" -C "$work/bundle" .
printf '%s\n' accounts config install accounts seed backend-api bulletin > "$work/expected"

# Copying the coordinator beside substitutes ensures no real lifecycle script runs.
for task in accounts config install seed
do
    cat > "$work/toolkit/quakestrikeph-$task.sh" <<'SH'
#!/bin/bash
set -eu
task=${0##*/quakestrikeph-}
task=${task%.sh}
case "$task" in
    accounts|seed)
        [ "$#" -eq 2 ] && [ "$1" = --directory ] && [ "$2" = "$TEST_APP" ] || exit 90 ;;
    config)
        [ "$#" -eq 4 ] && [ "$1" = --output ] && [ "$2" = "$TEST_CONFIG" ] &&
        [ "$3" = --directory ] && [ "$4" = "$TEST_APP" ] || exit 90 ;;
    install)
        [ "$#" -eq 6 ] && [ "$1" = --archive ] && [ "$2" = "$TEST_ARCHIVE" ] &&
        [ "$3" = --config ] && [ "$4" = "$TEST_CONFIG" ] &&
        [ "$5" = --directory ] && [ "$6" = "$TEST_APP" ] || exit 90 ;;
    *) exit 90 ;;
esac
[ "${DOCKER_HOST:-}" = unix:///var/run/docker.sock ] && [ -z "${DOCKER_CONTEXT:-}" ] || exit 90
echo "$task" >> "$TEST_LOG"
if [ "$(wc -l < "$TEST_LOG")" -eq "$TEST_FAIL_STAGE" ]; then echo 'Simulated stage failure.' >&2; exit 42; fi
if [ "$task" = config ]
then
    bash "$TEST_REAL_CONFIG" "$@"
elif [ "$task" = install ]
then
    mkdir -p "$TEST_APP/infrastructure"
    touch "$TEST_APP/infrastructure/compose.checkoff.yml"
    if [ ! -e "$TEST_APP/.env" ]; then cp "$TEST_CONFIG" "$TEST_APP/.env"; fi
fi
SH
done

cat > "$work/bin/docker" <<'SH'
#!/bin/bash
set -eu
# Compose now removes inherited test variables as well as application overrides.
# Read this harness's context from a private file instead.
source "$(dirname -- "$0")/test-context"
TEST_FAIL_STAGE=$(cat "$(dirname -- "$0")/fail-stage")
[ "${DOCKER_HOST:-}" = unix:///var/run/docker.sock ] && [ -z "${DOCKER_CONTEXT:-}" ] || exit 90
[ -z "${DOCKER_TLS_VERIFY:-}" ] && [ -z "${DOCKER_CERT_PATH:-}" ] && [ -z "${DOCKER_TLS:-}" ] || exit 90
[ "$WORKER_IMAGE_TAG" = local ] && [ "$BOOTSTRAP_RUN_MANIFEST" = /app/workers/bootstrap-snapshots/bootstrap-readiness.json ] || exit 90
[ "$1" = compose ] && [ "$2" = --project-name ] && [ "$3" = quakestrikeph-sam ] &&
[ "$4" = --env-file ] && [ "$5" = "$TEST_APP/.env" ] || exit 90
shift 5
for file in compose.yml compose.backend.yml compose.local.yml compose.release.yml compose.checkoff.yml
do
    [ "$1" = -f ] && [ "$2" = "$TEST_APP/infrastructure/$file" ] || exit 90
    shift 2
done
[ "$#" -eq 6 ] && [ "$1" = exec ] && [ "$2" = -T ] && [ "$4" = node ] && [ "$5" = -e ] || exit 90
case "$3" in
    backend-api) [[ "$6" == *http://127.0.0.1:3000/healthz* ]] || exit 90 ;;
    bulletin) [[ "$6" == *http://127.0.0.1:4321/* ]] || exit 90 ;;
    *) exit 90 ;;
esac
[[ "$6" == *'AbortSignal.timeout(10000)'* ]] || exit 90
echo "$3" >> "$TEST_LOG"
if [ "$(wc -l < "$TEST_LOG")" -eq "$TEST_FAIL_STAGE" ]; then echo 'Simulated stage failure.' >&2; exit 42; fi
SH
printf 'TEST_APP=%q\nTEST_LOG=%q\n' "$TEST_APP" "$TEST_LOG" > "$work/bin/test-context"
chmod +x "$work/bin/docker"
export PATH="$work/bin:$PATH"
[ "$(command -v docker)" = "$work/bin/docker" ]
export DOCKER_HOST=tcp://example.invalid:2376 DOCKER_CONTEXT=unrelated
export DOCKER_TLS_VERIFY=1 DOCKER_CERT_PATH=/nonexistent DOCKER_TLS=1

run_rebuild()
{
    printf '%s\n' "$TEST_FAIL_STAGE" > "$work/bin/fail-stage"
    bash "$script" --archive "$TEST_ARCHIVE" --config "$TEST_CONFIG" --directory "$TEST_APP"
}

# First run generates private test credentials; the second must preserve both copies.
run_rebuild > "$work/output" 2>&1
grep -q 'Disk space before rebuild' "$work/output"
cmp -s "$work/expected" "$TEST_LOG"
grep -q 'Full rebuild successful' "$work/output"
cp "$TEST_CONFIG" "$work/original.env"
for attempt in 1 2
do
    : > "$TEST_LOG"
    run_rebuild > "$work/output" 2>&1
    cmp -s "$work/expected" "$TEST_LOG"
    cmp -s "$work/original.env" "$TEST_CONFIG"
    cmp -s "$work/original.env" "$TEST_APP/.env"
done
rm -- "$TEST_CONFIG"
: > "$TEST_LOG"
run_rebuild > "$work/output" 2>&1
cmp -s "$work/original.env" "$TEST_CONFIG"
cmp -s "$work/expected" "$TEST_LOG"
echo 'PASS: order, quoted paths, local Docker, repeat runs, and credential recovery/preservation.'

# Every child failure and both final HTTP failures must stop later stages.
for TEST_FAIL_STAGE in 1 2 3 4 5 6 7
do
    export TEST_FAIL_STAGE
    : > "$TEST_LOG"
    if run_rebuild > "$work/output" 2>&1; then echo "FAIL: stage $TEST_FAIL_STAGE accepted"; exit 1; fi
    head -n "$TEST_FAIL_STAGE" "$work/expected" > "$work/prefix"
    cmp -s "$work/prefix" "$TEST_LOG"
    grep -q 'Simulated stage failure' "$work/output"
    grep -q 'Full rebuild failed:' "$work/output"
    if grep -q 'Full rebuild successful' "$work/output"; then exit 1; fi
    cmp -s "$work/original.env" "$TEST_CONFIG"
    cmp -s "$work/original.env" "$TEST_APP/.env"
done
export TEST_FAIL_STAGE=0
echo 'PASS: each stage failure stops execution without reporting success.'

expect_preflight_failure()
{
    local expected_message="$1"
    shift
    : > "$TEST_LOG"
    if bash "$script" "$@" > "$work/output" 2>&1; then echo 'FAIL: unsafe input accepted'; exit 1; fi
    grep -q "$expected_message" "$work/output"
    [ ! -s "$TEST_LOG" ]
}
for option in --archive --config --directory
do
    expect_preflight_failure 'requires a value' "$option"
    expect_preflight_failure 'requires a value' "$option" ''
    expect_preflight_failure 'requires a value' "$option" --help
done
expect_preflight_failure 'unknown option' --confirm
# A failed resource query must stop before any lifecycle stage runs.
printf '#!/bin/bash\necho "Simulated df failure" >&2\nexit 42\n' > "$work/bin/df"
chmod +x "$work/bin/df"
expect_preflight_failure 'could not check available disk space' --archive "$TEST_ARCHIVE" --config "$TEST_CONFIG" --directory "$TEST_APP"
rm -- "$work/bin/df"
expect_preflight_failure 'readable application archive'
expect_preflight_failure 'readable application archive' --archive "$work/missing"
printf 'corrupt\n' > "$work/corrupt.tar.gz"
expect_preflight_failure 'complete tar.gz' --archive "$work/corrupt.tar.gz" --config "$TEST_CONFIG" --directory "$TEST_APP"
expect_preflight_failure 'dedicated /srv/NAME' --archive "$TEST_ARCHIVE" --directory /
expect_preflight_failure 'outside the installation' --archive "$TEST_ARCHIVE" --config "$TEST_APP/.env" --directory "$TEST_APP"
ln -s "$TEST_CONFIG" "$work/linked.env"
expect_preflight_failure 'must not be a symlink' --archive "$TEST_ARCHIVE" --config "$work/linked.env" --directory "$TEST_APP"
mv "$work/toolkit/quakestrikeph-seed.sh" "$work/seed.sh"
expect_preflight_failure 'missing toolkit script' --archive "$TEST_ARCHIVE" --config "$TEST_CONFIG" --directory "$TEST_APP"
mv "$work/seed.sh" "$work/toolkit/quakestrikeph-seed.sh"
printf '\n# conflicting test configuration\n' >> "$TEST_CONFIG"
expect_preflight_failure 'differs from the installed' --archive "$TEST_ARCHIVE" --config "$TEST_CONFIG" --directory "$TEST_APP"
cp "$work/original.env" "$TEST_CONFIG"
rm -- "$TEST_APP/.env"
expect_preflight_failure 'its .env is missing' --archive "$TEST_ARCHIVE" --config "$TEST_CONFIG" --directory "$TEST_APP"
echo 'PASS: invalid arguments, archive, paths, missing scripts, and lost/conflicting credentials fail before stages.'
echo 'No real accounts, Docker services, databases, or demo credentials were changed.'
