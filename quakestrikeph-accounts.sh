#!/bin/bash

# Create the dedicated service account and apply least-privilege permissions.
# Authors: Armenta, Buergo, Candelaria, Pispis
# Usage: sudo bash quakestrikeph-accounts.sh [--directory /srv/quakestrikeph]
# AI assistance: Antigravity and ChatGPT helped simplify and review this script.
# Note: UID/GID 10001 match the application container user in QuakeStrikePH.

app_directory="/srv/quakestrikeph"
service_user="quakestrikeph"
service_group="quakestrikeph"
service_id=10001

fail()
{
    echo "Accounts setup failed: $*" >&2
    exit 1
}

while [ "$#" -gt 0 ]
do
    if [ "$1" = "--help" ]
    then
        echo "Usage: sudo bash quakestrikeph-accounts.sh [--directory PATH]"
        echo "Create the locked quakestrikeph service account (UID/GID 10001)"
        echo "and apply least-privilege permissions to the application directory."
        echo ""
        echo "Options:"
        echo "  --directory PATH  Application folder under /srv. Default: /srv/quakestrikeph"
        echo "  --help            Show this help message and exit."
        echo ""
        echo "Example:"
        echo "  sudo bash quakestrikeph-accounts.sh --directory /srv/quakestrikeph"
        exit 0

    elif [ "$1" = "--directory" ]
    then
        if [ "$#" -lt 2 ] || [ -z "$2" ]
        then
            fail "--directory requires a path."
        fi
        app_directory="${2%/}"
        shift 2

    else
        fail "unknown option '$1'. Use --help."
    fi
done

if [ "$EUID" -ne 0 ]
then
    fail "run this script with root privileges."
fi

for required_command in getent groupadd useradd mkdir chown chmod find
do
    if ! command -v "$required_command" > /dev/null
    then
        fail "$required_command is required."
    fi
done

# Keep the target inside /srv so we never change permissions on system folders.
case "$app_directory" in
    /srv/*) ;;
    *) fail "choose a dedicated folder inside /srv (for example /srv/quakestrikeph)." ;;
esac

# Create the service group if it does not already exist (safe to run twice).
if ! getent group "$service_group" > /dev/null
then
    groupadd --gid "$service_id" "$service_group" || fail "could not create group $service_group."
fi

# Create the locked service user if it does not already exist (no login shell, no sudo).
if ! getent passwd "$service_user" > /dev/null
then
    useradd --uid "$service_id" --gid "$service_group" \
        --no-create-home --home-dir /nonexistent \
        --shell /usr/sbin/nologin --password '!' \
        --comment "QuakeStrikePH service account" "$service_user" \
        || fail "could not create user $service_user."
fi

# Create the application directory if it does not exist yet.
mkdir -p "$app_directory" || fail "could not create $app_directory."

# Apply least-privilege permissions: root owns code, service group can read it.
chown -R root:"$service_group" "$app_directory" || fail "could not set ownership on $app_directory."
find "$app_directory" -type d -exec chmod 750 {} + || fail "could not set directory permissions."
find "$app_directory" -type f -exec chmod 640 {} + || fail "could not set file permissions."
find "$app_directory" -type f -name "*.sh" -exec chmod 750 {} + || fail "could not set script permissions."

# Keep the installed .env readable only by root.
if [ -f "$app_directory/.env" ]
then
    chown root:root "$app_directory/.env" || fail "could not set ownership on .env."
    chmod 600 "$app_directory/.env" || fail "could not set permissions on .env."
fi

echo "Accounts setup successful: $service_user ($service_id:$service_id)."
echo "Permissions applied to $app_directory."
exit 0
