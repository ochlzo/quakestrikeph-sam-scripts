#!/bin/bash

# Create the service account and protect the application files
# Authors: Armenta, Buergo, Candelaria, Pispis
# Usage: sudo bash quakestrikeph-accounts.sh --directory /srv/quakestrikeph
# Run before and after installation
# AI assistance: ChatGPT helped implement and verify this script.
# Match the user and group IDs to the worker image

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
        echo "Usage: sudo bash quakestrikeph-accounts.sh [--directory /srv/NAME] [--help]"
        echo "Create a locked quakestrikeph service user/group with UID/GID 10001."
        echo "Default directory: /srv/quakestrikeph. Use a dedicated directory directly under /srv."
        echo "Run before installation to create the account, and after installation to apply permissions."
        echo "Code: root-owned, service-group readable. Configuration: root-only, mode 600."
        echo "Bootstrap evidence: service-owned, directories 700 and files 600."
        echo "Existing compatible accounts are reused. No sudo or Docker-group access is granted."
        echo "Example: sudo bash quakestrikeph-accounts.sh --directory /srv/quakestrikeph"
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
    else
        echo "Error: unknown option '$1'. Use --help."
        exit 1
    fi
done

[ "$EUID" -eq 0 ] || fail "run with root privileges."
for required_command in getent id passwd groupadd useradd realpath find findmnt chown chmod install
do
    command -v "$required_command" > /dev/null || fail "$required_command is required."
done
[ -x /usr/sbin/nologin ] || fail "/usr/sbin/nologin is required."

# Check the target path muna to protect files outside the installation

[[ "$app_directory" =~ ^/srv/[a-zA-Z0-9._-]+$ ]] || fail "choose a dedicated /srv/NAME directory."
[ "$(realpath -m -- "$app_directory")" = "$app_directory" ] || fail "do not use dot segments or symlink paths."
[ ! -L "$app_directory" ] || fail "the application directory must not be a symlink."
[ ! -e "$app_directory" ] || [ -d "$app_directory" ] || fail "the target is not a directory."

# Check mounts muna so permission changes stay inside the installation
mounted_paths=$(findmnt -rn -o TARGET) || fail "could not inspect mounted filesystems."
while IFS= read -r mounted_path
do
    case "$mounted_path" in
        "$app_directory"|"$app_directory"/*) fail "unmount $mounted_path before changing permissions." ;;
    esac
done <<< "$mounted_paths"

if [ -d "$app_directory" ]
then
    first_entry=$(find "$app_directory" -mindepth 1 -maxdepth 1 -print -quit) || fail "could not inspect the directory."
    if [ -n "$first_entry" ]
    then
        [ -f "$app_directory/infrastructure/compose.checkoff.yml" ] &&
        [ -f "$app_directory/apps/quakestrikeph-bulletin/package.json" ] ||
            fail "nonempty directory is not an installation from the updated installer."
    fi
    # Block links muna to protect shared files
    linked_file=$(find "$app_directory" -xdev \( -type l -o \( -type f -links +1 \) \) -print -quit) ||
        fail "could not inspect links."
    [ -z "$linked_file" ] || fail "review linked file before proceeding: $linked_file"
fi

# Verify existing accounts muna to avoid taking over an ID

if group_record=$(getent group "$service_group")
then
    IFS=: read -r group_name group_password group_id group_members <<< "$group_record"
    [ "$group_id" = "$service_id" ] || fail "$service_group already has a different GID."
    [ -z "$group_members" ] || [ "$group_members" = "$service_user" ] ||
        fail "the service group has unrelated members."
elif getent group "$service_id" > /dev/null
then
    fail "GID $service_id belongs to another group."
fi

if user_record=$(getent passwd "$service_user")
then
    IFS=: read -r user_name user_password user_id user_group user_comment user_home user_shell <<< "$user_record"
    [ "$user_id" = "$service_id" ] && [ "$user_group" = "$service_id" ] &&
    [ "$user_home" = "/nonexistent" ] && [ "$user_shell" = "/usr/sbin/nologin" ] ||
        fail "the existing service account has incompatible settings."
    [ "$(id -G "$service_user")" = "$service_id" ] || fail "the service account has additional groups."
    password_status=$(passwd -S "$service_user") || fail "could not check account lock status."
    read -r account_name lock_status remaining_status <<< "$password_status"
    [ "$lock_status" = "L" ] || fail "the existing service account is not password-locked."
elif getent passwd "$service_id" > /dev/null
then
    fail "UID $service_id belongs to another user."
fi

# Reuse matching identities kapag present
if ! getent group "$service_group" > /dev/null
then
    groupadd --gid "$service_id" "$service_group" || fail "could not create the service group."
fi
if ! getent passwd "$service_user" > /dev/null
then
    useradd --uid "$service_id" --gid "$service_group" --no-create-home \
        --home-dir /nonexistent --shell /usr/sbin/nologin --password '!' \
        --comment "QuakeStrikePH container worker" "$service_user" || fail "could not create the service user."
fi

install -d -o root -g "$service_group" -m 750 -- "$app_directory" || fail "could not prepare the application directory."

# Keep application code read only para sa workers
# Windows archives can mark pati ordinary files as executable
# Give execute permission only sa directories and shell scripts

find "$app_directory" -xdev \
    \( -path "$app_directory/.env" -o -path "$app_directory/bootstrap-snapshots" \) -prune -o \
    \( -type d -o -type f \) -exec chown root:"$service_group" {} + || fail "could not set code ownership."
find "$app_directory" -xdev \
    \( -path "$app_directory/.env" -o -path "$app_directory/bootstrap-snapshots" \) -prune -o \
    -type d -exec chmod 750 {} + || fail "could not protect code directories."
find "$app_directory" -xdev \
    \( -path "$app_directory/.env" -o -path "$app_directory/bootstrap-snapshots" \) -prune -o \
    -type f ! -name '*.sh' -exec chmod 640 {} + || fail "could not protect code files."
find "$app_directory" -xdev \
    \( -path "$app_directory/.env" -o -path "$app_directory/bootstrap-snapshots" \) -prune -o \
    -type f -name '*.sh' -exec chmod 750 {} + || fail "could not protect shell scripts."

# Restrict the environment file to root para safe ang credentials
if [ -f "$app_directory/.env" ]
then
    chown root:root "$app_directory/.env" && chmod 600 "$app_directory/.env" || fail "could not protect .env."
fi

# Let the worker save readiness data sa evidence directory
if [ -f "$app_directory/infrastructure/compose.checkoff.yml" ]
then
    evidence_directory="$app_directory/bootstrap-snapshots"
    install -d -o "$service_user" -g "$service_group" -m 700 -- "$evidence_directory" || fail "could not prepare evidence storage."
    find "$evidence_directory" -xdev -type d -exec chown "$service_user:$service_group" {} + \
        -exec chmod 700 {} + || fail "could not protect evidence directories."
    find "$evidence_directory" -xdev -type f -exec chown "$service_user:$service_group" {} + \
        -exec chmod 600 {} + || fail "could not protect evidence files."
fi

echo "Accounts setup successful: $service_user ($service_id:$service_id)."
echo "Permissions applied to $app_directory. No database volumes or credentials were replaced."
