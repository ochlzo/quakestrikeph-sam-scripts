#!/bin/bash

# Remove only the dedicated local course deployment. Preview is the default.
# Authors: Armenta, Buergo, Candelaria, Pispis
# Usage: sudo bash quakestrikeph-uninstall.sh --directory /srv/quakestrikeph
# This previews removal; --confirm enables deletion. Use --help for details.
# AI assistance: ChatGPT helped implement and test this script.
# Sources: application Compose files and Docker's container/volume removal docs:
# https://docs.docker.com/reference/cli/docker/container/rm/
# https://docs.docker.com/reference/cli/docker/volume/ls/

app_directory="/srv/quakestrikeph"
project="quakestrikeph-sam"
service_user="quakestrikeph"
service_id=10001
confirmed=false

fail()
{
    echo "Uninstall failed: $*" >&2
    exit 1
}

while [ "$#" -gt 0 ]
do
    if [ "$1" = "--help" ]
    then
        echo "Usage: sudo bash quakestrikeph-uninstall.sh [--directory /srv/NAME] [--confirm]"
        echo "Preview removal of the quakestrikeph-sam deployment by default."
        echo "--confirm permanently removes its containers, database/cache volumes, networks,"
        echo "installed files (including .env and bootstrap evidence), and service account/group."
        echo "Default directory: /srv/quakestrikeph. Only a dedicated /srv/NAME is accepted."
        echo "Keeps Docker, cached images, archives, and configuration outside the install directory."
        echo "Uses the local Ubuntu/Debian Docker socket, never a remote Docker context."
        echo "Requires Docker to respond, even for a repeated uninstall. Back up needed data first."
        echo "Example (preview only): sudo bash quakestrikeph-uninstall.sh --directory /srv/quakestrikeph"
        exit 0
    elif [ "$1" = "--directory" ]
    then
        if [ "$#" -lt 2 ] || [ -z "$2" ] || [[ "$2" == --* ]]
        then
            echo "Error: --directory requires a value."
            exit 1
        fi
        app_directory="${2%/}"
        shift 2
    elif [ "$1" = "--confirm" ]
    then
        confirmed=true
        shift
    else
        echo "Error: unknown option '$1'. Use --help."
        exit 1
    fi
done

[ "$EUID" -eq 0 ] || fail "run with root privileges."
for required_command in docker getent id passwd realpath find findmnt userdel groupdel rm
do
    command -v "$required_command" > /dev/null || fail "$required_command is required."
done

# Use the course server's local engine even if a shell has another context selected.
docker_local()
{
    DOCKER_CONTEXT= DOCKER_HOST= DOCKER_TLS= DOCKER_TLS_VERIFY= \
        docker --host unix:///var/run/docker.sock "$@"
}

# Validate every target before stopping a service or deleting anything.
[[ "$app_directory" =~ ^/srv/[a-zA-Z0-9._-]+$ ]] || fail "choose a dedicated /srv/NAME directory."
[ "$(realpath -m -- "$app_directory")" = "$app_directory" ] || fail "do not use dot segments or symlink paths."
[ ! -L "$app_directory" ] || fail "the application directory must not be a symlink."
[ ! -e "$app_directory" ] || [ -d "$app_directory" ] || fail "target is not a directory."
mounted_paths=$(findmnt -rn -o TARGET) || fail "could not inspect mounted filesystems."
while IFS= read -r mounted_path
do
    case "$mounted_path" in
        "$app_directory"|"$app_directory"/*) fail "unmount $mounted_path before uninstalling." ;;
    esac
done <<< "$mounted_paths"

recognized_install=false
if [ -f "$app_directory/infrastructure/compose.checkoff.yml" ] &&
   [ -f "$app_directory/apps/quakestrikeph-bulletin/package.json" ]
then
    recognized_install=true
elif [ -d "$app_directory" ]
then
    first_entry=$(find "$app_directory" -mindepth 1 -maxdepth 1 -print -quit) || fail "could not inspect the directory."
    [ -z "$first_entry" ] || fail "nonempty directory is not a recognized course installation."
fi

docker_local info > /dev/null || fail "local Docker is unavailable; nothing was removed."
containers=$(docker_local ps -aq --filter "label=com.docker.compose.project=$project") || fail "could not list containers."
volumes=$(docker_local volume ls -q --filter "label=com.docker.compose.project=$project") || fail "could not list volumes."
networks=$(docker_local network ls -q --filter "label=com.docker.compose.project=$project") || fail "could not list networks."
if [ -n "$containers$volumes$networks" ] && [ "$recognized_install" != true ]
then
    fail "project resources exist but this directory is not recognized; restore the install files for inspection."
fi

for container in $containers
do
    [[ "$container" =~ ^[0-9a-f]{12,64}$ ]] || fail "unexpected container identifier."
    working_directory=$(docker_local inspect --format '{{index .Config.Labels "com.docker.compose.project.working_dir"}}' "$container") || fail "could not inspect container ownership."
    [ "$working_directory" = "$app_directory/infrastructure" ] || fail "a project container belongs to a different installation directory."
done
for volume in $volumes
do
    case "$volume" in
        "${project}_postgres_data"|"${project}_redis_data") ;;
        *) fail "unexpected project volume: $volume; review it before uninstalling." ;;
    esac
done
for network in $networks
do
    [[ "$network" =~ ^[0-9a-f]{12,64}$ ]] || fail "unexpected network identifier."
done

if user_record=$(getent passwd "$service_user")
then
    IFS=: read -r user_name password user_id user_group comment user_home user_shell <<< "$user_record"
    [ "$user_id" = "$service_id" ] && [ "$user_group" = "$service_id" ] &&
    [ "$user_home" = /nonexistent ] && [ "$user_shell" = /usr/sbin/nologin ] || fail "service account identity differs; no removal attempted."
    [ "$(id -G "$service_user")" = "$service_id" ] || fail "service account has additional groups."
    password_status=$(passwd -S "$service_user") || fail "could not check service account lock."
    read -r account_name lock_status remaining_status <<< "$password_status"
    [ "$lock_status" = L ] || fail "service account is not password-locked."
elif getent passwd "$service_id" > /dev/null
then
    fail "UID $service_id belongs to another account."
fi
if group_record=$(getent group "$service_user")
then
    IFS=: read -r group_name password group_id members <<< "$group_record"
    [ "$group_id" = "$service_id" ] || fail "service group identity differs."
    [ -z "$members" ] || [ "$members" = "$service_user" ] || fail "service group contains unrelated members."
elif getent group "$service_id" > /dev/null
then
    fail "GID $service_id belongs to another group."
fi

echo "Removal target: $app_directory and Compose project $project"
printf 'Containers: %s\nVolumes: %s\nNetworks: %s\n' "${containers:-none}" "${volumes:-none}" "${networks:-none}"
echo "Service account/group: $service_user, if present."
echo "The installed .env, bootstrap evidence, and database records will be lost."
if [ "$confirmed" != true ]
then
    echo "Preview only: nothing removed. Use --confirm only when deletion is intended."
    exit 0
fi

for container in $containers
do
    docker_local stop "$container" || fail "could not stop $container; cleanup stopped."
    # --volumes removes anonymous container storage; named data volumes are handled below.
    docker_local rm --volumes "$container" || fail "could not remove $container; cleanup stopped."
done
for volume in $volumes
do
    # No force: Docker must refuse a volume still referenced by another container.
    docker_local volume rm "$volume" || fail "could not remove $volume; install files and account retained."
done
for network in $networks
do
    docker_local network rm "$network" || fail "could not remove a network; install files and account retained."
done

if [ -d "$app_directory" ]
then
    rm -rf --one-file-system --preserve-root=all -- "$app_directory" || fail "could not remove the installation directory."
fi
if getent passwd "$service_user" > /dev/null
then
    # No --force or --remove: do not kill unrelated processes or traverse a home directory.
    userdel "$service_user" || fail "could not remove service user; inspect remaining processes and retry."
fi
if getent group "$service_user" > /dev/null
then
    groupdel "$service_user" || fail "could not remove service group; inspect other memberships."
fi

containers=$(docker_local ps -aq --filter "label=com.docker.compose.project=$project") || fail "could not verify containers."
volumes=$(docker_local volume ls -q --filter "label=com.docker.compose.project=$project") || fail "could not verify volumes."
networks=$(docker_local network ls -q --filter "label=com.docker.compose.project=$project") || fail "could not verify networks."
[ -z "$containers$volumes$networks" ] && [ ! -e "$app_directory" ] || fail "some deployment resources remain."
if getent passwd "$service_user" > /dev/null || getent group "$service_user" > /dev/null
then
    fail "service account or group remains."
fi
echo "Uninstall successful: course deployment removed."
echo "Docker, cached images, and preparation files outside the installation directory were retained."
