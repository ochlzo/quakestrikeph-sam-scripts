#!/bin/bash

# Prepare private settings for the course demo
# Authors: Armenta, Buergo, Candelaria, Pispis
# Usage: sudo bash quakestrikeph-config.sh --output /root/demo.env --directory /srv/quakestrikeph
# Run before installation and reuse matching credentials
# AI assistance: ChatGPT helped implement and test this script.
# Settings adapted from the application's .env.example, local-runtime guide,
# and workers/tests/fixtures/bootstrap/historical_snapshot.json.

# Hide passwords kahit may Bash tracing
set +x
output_file="/root/demo.env"
app_directory="/srv/quakestrikeph"

fail()
{
    echo "Configuration setup failed: $*" >&2
    exit 1
}

while [ "$#" -gt 0 ]
do
    if [ "$1" = "--help" ]
    then
        echo "Usage: sudo bash quakestrikeph-config.sh [--output FILE] [--directory PATH] [--help]"
        echo "Prepare a private local demo configuration. Default output: /root/demo.env"
        echo "Default installation directory: /srv/quakestrikeph"
        echo "Existing files are checked and kept unchanged, never repaired or overwritten."
        echo "If output is missing, reuse the installed .env before generating new passwords."
        echo "New files use four distinct 64-character hexadecimal passwords and mode 600."
        echo "Use a private Linux directory outside Git; no credentials are printed."
        echo "Example: sudo bash quakestrikeph-config.sh --output /root/demo.env --directory /srv/quakestrikeph"
        exit 0
    elif [ "$1" = "--output" ] || [ "$1" = "--directory" ]
    then
        if [ "$#" -lt 2 ] || [ -z "$2" ] || [[ "$2" == --* ]]
        then
            echo "Error: $1 requires a value."
            exit 1
        fi
        if [ "$1" = "--output" ]; then output_file="$2"; else app_directory="$2"; fi
        shift 2
    else
        echo "Error: unknown option '$1'. Use --help."
        exit 1
    fi
done

[ "$EUID" -eq 0 ] || fail "run with root privileges."
for required_command in realpath dirname stat grep cmp openssl mktemp cp cat chown ln rm
do
    command -v "$required_command" > /dev/null || fail "$required_command is required."
done

# Read the configuration as data lang to avoid executing it
read_setting()
{
    local config_file="$1" setting_name="$2" entry
    entry=$(grep -E "^$setting_name=" "$config_file") || fail "missing $setting_name; file unchanged."
    # Stop kapag duplicate ang key
    [[ "$entry" != *$'\n'* ]] || fail "duplicate $setting_name; file unchanged."
    [ -n "${entry#*=}" ] || fail "$setting_name is empty; file unchanged."
    printf '%s' "${entry#*=}"
}

check_config()
{
    local checked_file="$1" password_key password_value setting_value
    [ ! -L "$checked_file" ] && [ -f "$checked_file" ] || fail "configuration must be a regular file, not a symlink."
    [ "$(stat -c '%u:%h' "$checked_file")" = "0:1" ] || fail "configuration must be root-owned with no hard links."
    case "$(stat -c '%a' "$checked_file")" in
        600|400) ;;
        *) fail "configuration needs mode 600 or 400; file unchanged." ;;
    esac
    if grep -q $'\r' "$checked_file"; then fail "use LF line endings; file unchanged."; fi

    for password_key in POSTGRES_PASSWORD MIGRATION_DB_PASSWORD WORKER_DB_PASSWORD BACKEND_DB_PASSWORD
    do
        password_value=$(read_setting "$checked_file" "$password_key") || return 1
        [[ "$password_value" =~ ^[0-9a-f]{64}$ ]] || fail "$password_key is not in the demo's 64-hex format; file unchanged."
    done
    password_value=$(read_setting "$checked_file" MIGRATION_DB_PASSWORD) || return 1
    setting_value=$(read_setting "$checked_file" MIGRATION_DATABASE_URL) || return 1
    [ "$setting_value" = "postgresql+psycopg://quakestrike_migration:$password_value@postgres:5432/quakestrike" ] || fail "migration URL/password mismatch; file unchanged."
    password_value=$(read_setting "$checked_file" WORKER_DB_PASSWORD) || return 1
    setting_value=$(read_setting "$checked_file" DATABASE_URL) || return 1
    [ "$setting_value" = "postgresql+psycopg://quakestrike_worker:$password_value@postgres:5432/quakestrike" ] || fail "worker URL/password mismatch; file unchanged."
    password_value=$(read_setting "$checked_file" BACKEND_DB_PASSWORD) || return 1
    setting_value=$(read_setting "$checked_file" BACKEND_DATABASE_URL) || return 1
    [ "$setting_value" = "postgresql://quakestrike_backend:$password_value@postgres:5432/quakestrike" ] || fail "backend URL/password mismatch; file unchanged."

    for expected_setting in \
        'REDIS_URL=redis://redis:6379/0' \
        'MODEL_ARTIFACT_HOST_DIRECTORY=../model-artifacts' \
        'MODEL_RELEASE_ID=a7f2286b-13a2-4708-a04d-4139281a4e1f' \
        'BOOTSTRAP_REQUIRED_AVAILABLE_THROUGH=2026-09-01T00:00:00+08:00'
    do
        setting_value=$(read_setting "$checked_file" "${expected_setting%%=*}") || return 1
        [ "$setting_value" = "${expected_setting#*=}" ] || fail "${expected_setting%%=*} does not match this demo; file unchanged."
    done
    for setting_name in BACKEND_IMAGE_TAG PHIVOLCS_CATALOG_URL
    do
        read_setting "$checked_file" "$setting_name" > /dev/null || return 1
    done
    for setting_name in POSTGRES_DB POSTGRES_USER
    do
        if grep -q "^$setting_name=" "$checked_file"
        then
            setting_value=$(read_setting "$checked_file" "$setting_name") || return 1
            [ "$setting_value" = "quakestrike" ] || fail "$setting_name must be quakestrike; file unchanged."
        fi
    done
}

[ ! -L "$output_file" ] || fail "output must not be a symlink."
output_file=$(realpath -m -- "$output_file") || fail "could not resolve output path."
app_directory=$(realpath -m -- "$app_directory") || fail "could not resolve installation path."
installed_config="$app_directory/.env"

if [ -e "$output_file" ]
then
    check_config "$output_file" || exit 1
    if [ -e "$installed_config" ] || [ -L "$installed_config" ]
    then
        check_config "$installed_config" || exit 1
        # Compare both files muna to protect installed credentials
        cmp -s -- "$output_file" "$installed_config" || fail "output differs from the installed .env; both files unchanged."
    fi
    echo "Configuration ready: existing file kept unchanged."
    exit 0
fi

output_parent=$(dirname -- "$output_file")
[ -d "$output_parent" ] || fail "create the private output directory first."
[ "$(stat -c '%u' "$output_parent")" = "0" ] || fail "output directory must be root-owned."
parent_mode=$(stat -c '%a' "$output_parent") || fail "could not check output directory."
(( (8#$parent_mode & 0022) == 0 )) || fail "output directory must not be writable by group or others."

# Reuse installed settings kapag missing ang external copy
reuse_installed=false
if [ -e "$installed_config" ] || [ -L "$installed_config" ]
then
    check_config "$installed_config" || exit 1
    reuse_installed=true
elif [ -e "$app_directory/infrastructure/compose.checkoff.yml" ]
then
    fail "installation exists but its .env is missing; recover the original credentials first."
fi

# Set private permissions muna for the temporary file
umask 077
temporary_file=$(mktemp "$output_parent/.quakestrikeph-config.XXXXXX") || fail "could not create private temporary file."
# Clean up the temporary file kahit may error
trap 'rm -f -- "$temporary_file"' EXIT

if [ "$reuse_installed" = true ]
then
    cp -- "$installed_config" "$temporary_file" || fail "could not copy installed configuration."
else
    postgres_password=$(openssl rand -hex 32) || fail "password generation failed."
    migration_password=$(openssl rand -hex 32) || fail "password generation failed."
    worker_password=$(openssl rand -hex 32) || fail "password generation failed."
    backend_password=$(openssl rand -hex 32) || fail "password generation failed."
    [ "$postgres_password" != "$migration_password" ] && [ "$postgres_password" != "$worker_password" ] &&
    [ "$postgres_password" != "$backend_password" ] && [ "$migration_password" != "$worker_password" ] &&
    [ "$migration_password" != "$backend_password" ] && [ "$worker_password" != "$backend_password" ] || fail "generated passwords were not distinct."

    if ! cat > "$temporary_file" <<ENV
# Private local course demo. Generated with AI-assisted quakestrikeph-config.sh.
POSTGRES_DB=quakestrike
POSTGRES_USER=quakestrike
POSTGRES_PASSWORD=$postgres_password
MIGRATION_DB_PASSWORD=$migration_password
WORKER_DB_PASSWORD=$worker_password
BACKEND_DB_PASSWORD=$backend_password
MIGRATION_DATABASE_URL=postgresql+psycopg://quakestrike_migration:$migration_password@postgres:5432/quakestrike
DATABASE_URL=postgresql+psycopg://quakestrike_worker:$worker_password@postgres:5432/quakestrike
BACKEND_DATABASE_URL=postgresql://quakestrike_backend:$backend_password@postgres:5432/quakestrike
REDIS_URL=redis://redis:6379/0
ACCOUNT_REDIS_URL=redis://redis:6379/0
BACKEND_IMAGE_TAG=local
WORKER_IMAGE_TAG=local
MODEL_RELEASE_ID=a7f2286b-13a2-4708-a04d-4139281a4e1f
MODEL_ARTIFACT_DIRECTORY=/app/model-artifacts
MODEL_ARTIFACT_HOST_DIRECTORY=../model-artifacts
BOOTSTRAP_RUN_MANIFEST=/app/workers/bootstrap-snapshots/bootstrap-readiness.json
BOOTSTRAP_REQUIRED_AVAILABLE_THROUGH=2026-09-01T00:00:00+08:00
PHIVOLCS_CATALOG_URL=https://earthquake.phivolcs.dost.gov.ph/earthquake-information
PUBLIC_BULLETIN_BASE_URL=http://127.0.0.1:4321
ALERT_RESOLUTION_ENABLED=false
ALERT_DELIVERY_ENABLED=false
ENV
    then
        fail "could not write new configuration."
    fi
fi

chown root:root "$temporary_file" || fail "could not set private file ownership."
check_config "$temporary_file" || exit 1
# Use a hard link para existing output files stay intact
ln -- "$temporary_file" "$output_file" || fail "could not create output; an existing file was not overwritten."
rm -- "$temporary_file" || fail "configuration saved but temporary file cleanup failed."
trap - EXIT
if [ "$reuse_installed" = true ]
then
    echo "Configuration ready: copied installed settings without changing credentials."
else
    echo "Configuration ready: created a new private demo file."
fi
echo "Use this file as the installer's --config argument: $output_file"
