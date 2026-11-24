#!/bin/bash

# Remove only the QuakeStrikePH deployment, its database volumes, and its service account.
# Authors: Armenta, Buergo, Candelaria, Pispis
# Usage: sudo bash quakestrikeph-uninstall.sh [--directory /srv/quakestrikeph] [--confirm]
# AI assistance: GPT 6.2 Sol (Codex) and Gemini 4 Neon (Antigravity) assisted with edge-case checks, refactoring, and review (see inline notes).

app_directory="/srv/quakestrikeph"
project="quakestrikeph-sam"
service_user="quakestrikeph"
service_group="quakestrikeph"
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
        echo "Usage: sudo bash quakestrikeph-uninstall.sh [--directory PATH] [--confirm]"
        echo "Preview removal of the QuakeStrikePH deployment by default."
        echo "Add --confirm to permanently delete its containers, volumes, networks,"
        echo "application folder, and service account without touching Docker or other apps."
        echo ""
        echo "Options:"
        echo "  --directory PATH  Application folder under /srv. Default: /srv/quakestrikeph"
        echo "  --confirm         Perform deletion instead of previewing."
        echo "  --help            Show this help message and exit."
        echo ""
        echo "Example (preview only):"
        echo "  sudo bash quakestrikeph-uninstall.sh --directory /srv/quakestrikeph"
        exit 0

    elif [ "$1" = "--directory" ]
    then
        if [ "$#" -lt 2 ] || [ -z "$2" ]
        then
            fail "--directory requires a path."
        fi
        app_directory="${2%/}"
        shift 2

    elif [ "$1" = "--confirm" ]
    then
        confirmed=true
        shift

    else
        fail "unknown option '$1'. Use --help."
    fi
done

if [ "$EUID" -ne 0 ]
then
    fail "run this script with root privileges."
fi

for required_command in docker getent userdel groupdel rm
do
    if ! command -v "$required_command" > /dev/null
    then
        fail "$required_command is required."
    fi
done

case "$app_directory" in
    /srv/*) ;;
    *) fail "choose a dedicated folder inside /srv (for example /srv/quakestrikeph)." ;;
esac

docker info > /dev/null || fail "Docker is not responding; nothing was removed."

# AI-assisted: scope Docker removal strictly to quakestrikeph-sam via Compose project label filters.
containers=$(docker ps -aq --filter "label=com.docker.compose.project=$project") || fail "could not list containers."
volumes=$(docker volume ls -q --filter "label=com.docker.compose.project=$project") || fail "could not list volumes."
networks=$(docker network ls -q --filter "label=com.docker.compose.project=$project") || fail "could not list networks."

echo "Removal target: $app_directory (Compose project: $project)"
echo "Containers: ${containers:-none}"
echo "Volumes:    ${volumes:-none}"
echo "Networks:   ${networks:-none}"
echo "Account:    $service_user (if present)"

if [ "$confirmed" != true ]
then
    echo "Preview only: nothing removed. Add --confirm to delete."
    exit 0
fi

for container in $containers
do
    docker stop "$container" || fail "could not stop container $container."
    docker rm --volumes "$container" || fail "could not remove container $container."
done

for volume in $volumes
do
    docker volume rm "$volume" || fail "could not remove volume $volume."
done

for network in $networks
do
    docker network rm "$network" || fail "could not remove network $network."
done

if [ -d "$app_directory" ]
then
    rm -rf -- "$app_directory" || fail "could not remove $app_directory."
fi

if getent passwd "$service_user" > /dev/null
then
    userdel "$service_user" || fail "could not remove user $service_user."
fi

if getent group "$service_group" > /dev/null
then
    groupdel "$service_group" || fail "could not remove group $service_group."
fi

echo "Uninstall successful: QuakeStrikePH deployment removed."
echo "Docker, cached images, backups, and external .env files were kept."
exit 0
