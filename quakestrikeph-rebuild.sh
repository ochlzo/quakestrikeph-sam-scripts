#!/bin/bash

# Run the offline deployment and check the finished demo
# Authors: Armenta, Buergo, Candelaria, Pispis
# Usage: bash quakestrikeph-rebuild.sh --help
# AI assistance: ChatGPT helped implement and test this script.
# Stage order follows this repository's README. Final HTTP checks are adapted
# from quakestrikeph-install.sh and the application's Compose health checks.

app_directory="/srv/quakestrikeph"
app_archive=""
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
        echo "Usage: sudo bash quakestrikeph-rebuild.sh --archive FILE [--config FILE] [--directory /srv/NAME]"
        echo "Run accounts, configuration, installation, final permissions, seed, and HTTP checks."
        echo "  --archive FILE    Required trusted application .tar.gz with both image archives."
        echo "  --config FILE     Private configuration to reuse or create. Default: /root/demo.env"
        echo "  --directory PATH  Dedicated installation directory. Default: /srv/quakestrikeph"
        echo "  --help            Show this help and exit."
        echo "Example: sudo bash quakestrikeph-rebuild.sh --archive /root/quakestrikeph-with-prediction.tar.gz"
        echo "Prepare the offline bundle and cached APT packages as described in README.md."
        echo "Reports disk space for /tmp, /srv, and /var/lib before starting deployment."
        echo "Keep all toolkit scripts together, outside the installation directory."
        echo "Existing credentials are reused; new credentials are generated only for a new setup."
        echo "This uses local Docker and never calls uninstall or deletes database volumes."
        echo "A rerun briefly stops application services during installation."
        echo "Exit status: 0 on success, 1 on failure. Failed stages are not rolled back."
        exit 0
    elif [ "$1" = "--archive" ] || [ "$1" = "--config" ] || [ "$1" = "--directory" ]
    then
        if [ "$#" -lt 2 ] || [ -z "$2" ] || [[ "$2" == --* ]]
        then
            echo "Error: $1 requires a value." >&2
            exit 1
        fi
        if [ "$1" = "--archive" ]
        then
            app_archive="$2"
        elif [ "$1" = "--config" ]
        then
            config_file="$2"
        else
            app_directory="${2%/}"
        fi
        shift 2
    else
        echo "Error: unknown option '$1'. Use --help." >&2
        exit 1
    fi
done

[ "$EUID" -eq 0 ] || fail "run with root privileges."
for required_command in bash realpath dirname tar cmp env df
do
    command -v "$required_command" > /dev/null || fail "$required_command is required."
done


# Check for missing inputs and unsafe paths muna

[ -f "$app_archive" ] && [ -r "$app_archive" ] || fail "use --archive to supply a readable application archive."
app_archive=$(realpath -e -- "$app_archive") || fail "could not resolve archive path."
[[ "$app_directory" =~ ^/srv/[a-zA-Z0-9._-]+$ ]] || fail "choose a dedicated /srv/NAME directory."
[ "$(realpath -m -- "$app_directory")" = "$app_directory" ] || fail "do not use dot segments or symlink paths."
[ ! -e "$app_directory" ] || [ -d "$app_directory" ] || fail "the target is not a directory."
[ ! -L "$config_file" ] || fail "configuration must not be a symlink."
config_file=$(realpath -m -- "$config_file") || fail "could not resolve configuration path."
[ -d "$(dirname -- "$config_file")" ] || fail "create the private configuration directory first."
script_path=$(realpath -e -- "$0") || fail "could not locate this script."
script_directory=$(dirname -- "$script_path")
# Keep rebuild inputs outside the install directory para safe during redeployment
for input_path in "$app_archive" "$config_file" "$script_directory"
do
    case "$input_path" in
        "$app_directory"|"$app_directory"/*) fail "keep the archive, configuration, and toolkit outside the installation directory." ;;
    esac
done
# Check companion scripts muna before changing the server
for script in quakestrikeph-accounts.sh quakestrikeph-config.sh quakestrikeph-install.sh quakestrikeph-seed.sh
do
    [ -f "$script_directory/$script" ] && [ -r "$script_directory/$script" ] || fail "missing toolkit script: $script"
    bash -n "$script_directory/$script" || fail "syntax error in $script"
done

# Show free space para sa extraction application files and Docker
echo "Disk space before rebuild (/tmp, /srv, /var/lib):"
df -h -- /tmp /srv /var/lib || fail "could not check available disk space."

# Check the archive muna for damage
tar -tzf "$app_archive" > /dev/null || fail "the application archive is not readable as a complete tar.gz."

# Check for credential conflicts muna before changing permissions

# The config script reuses installed settings kapag missing ang external copy
if [ -e "$app_directory/.env" ] || [ -L "$app_directory/.env" ]
then
    [ -f "$app_directory/.env" ] && [ ! -L "$app_directory/.env" ] || fail "installed configuration must be a regular file."
    if [ -e "$config_file" ]
    then
        cmp -s -- "$config_file" "$app_directory/.env" || fail "configuration differs from the installed .env; recover the matching credentials."
    fi
elif [ -e "$app_directory/infrastructure/compose.checkoff.yml" ]
then
    fail "installation exists but its .env is missing; recover the original credentials first."
fi

# Use one local Docker engine para consistent ang rebuild
export DOCKER_HOST=unix:///var/run/docker.sock
unset DOCKER_CONTEXT DOCKER_TLS_VERIFY DOCKER_CERT_PATH DOCKER_TLS

# Prepare the account and configuration muna for installation
echo "Step 1/6: prepare the service account and directory..."
bash "$script_directory/quakestrikeph-accounts.sh" --directory "$app_directory" || fail "initial accounts setup failed."

echo "Step 2/6: prepare or reuse private configuration..."
bash "$script_directory/quakestrikeph-config.sh" --output "$config_file" --directory "$app_directory" || fail "configuration setup failed."

echo "Step 3/6: install the prepared release..."
bash "$script_directory/quakestrikeph-install.sh" --archive "$app_archive" --config "$config_file" --directory "$app_directory" || fail "installation failed."

# Reapply permissions pagkatapos ng installation to cover copied files
echo "Step 4/6: apply final permissions..."
bash "$script_directory/quakestrikeph-accounts.sh" --directory "$app_directory" || fail "final permissions failed."

echo "Step 5/6: seed test records and verify the saved forecast..."
bash "$script_directory/quakestrikeph-seed.sh" --directory "$app_directory" || fail "seed or saved forecast verification failed."

compose()
{   
  
    # Reuse the same Compose settings para sa final checks
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

# Check both web services bago reporting success
# The saved forecast is already verified sa seed stage
# Check URLs inside the containers para independent of Windows port forwarding
echo "Step 6/6: verify the Backend and Bulletin responses..."
compose exec -T backend-api node -e "fetch('http://127.0.0.1:3000/healthz', {signal: AbortSignal.timeout(10000)}).then(r => process.exit(r.ok ? 0 : 1)).catch(error => { console.error(error.message); process.exit(1); })" || fail "Backend HTTP check failed."
compose exec -T bulletin node -e "fetch('http://127.0.0.1:4321/', {signal: AbortSignal.timeout(10000)}).then(r => process.exit(r.ok ? 0 : 1)).catch(error => { console.error(error.message); process.exit(1); })" || fail "Bulletin HTTP check failed."

echo "Full rebuild successful: web responses passed and the demo forecast is saved."
echo "Open http://127.0.0.1:4321 on the host and select Sanitized prediction anchor."
exit 0
