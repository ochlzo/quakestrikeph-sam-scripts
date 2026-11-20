#!/bin/bash

# Prepare the six-file toolkit and offline network in a fresh test import.
# Repository authors: Armenta, Buergo, Candelaria, Pispis
# Usage: bash rehearsal-wsl/prepare-fresh-test.sh --help
# AI assistance: Codex implemented the preparation documented in this directory.

fail()
{
    echo "Fresh test preparation failed: $*" >&2
    exit 1
}

if [ "$#" -eq 1 ] && [ "$1" = --help ]
then
    echo "Usage: bash rehearsal-wsl/prepare-fresh-test.sh [--shell] ARCHIVE.tar.gz"
    echo "Run as root inside QuakeStrikePH-FreshTest. Keep ARCHIVE.tar.gz.sha256 beside the archive."
    echo "--shell opens the toolkit in the offline network after preparation passes."
    echo "Example: bash rehearsal-wsl/prepare-fresh-test.sh --shell /mnt/c/Users/armen/quakestrikeph-with-prediction.tar.gz"
    exit 0
fi

open_shell=false
if [ "${1:-}" = --shell ]
then
    open_shell=true
    shift
fi
[ "$#" -eq 1 ] && [[ "$1" != --* ]] || fail "supply one archive path or use --help."
[ "${WSL_DISTRO_NAME:-}" = QuakeStrikePH-FreshTest ] ||
    fail "run inside QuakeStrikePH-FreshTest."
[ "$EUID" -eq 0 ] || fail "run as root."
[ -d /run/systemd/system ] || fail "enable systemd in the fresh import first."
source /etc/os-release || fail "could not identify this Linux installation."
[ "${ID:-}:${VERSION_ID:-}" = ubuntu:24.04 ] ||
    fail "use the prepared Ubuntu 24.04 backup. The Docker service settings depend on that release."

for installed_path in /usr/bin/docker /usr/bin/dockerd /usr/bin/containerd \
    /run/docker.sock /srv/quakestrikeph /root/fresh-test.env
do
    [ ! -e "$installed_path" ] && [ ! -L "$installed_path" ] ||
        fail "$installed_path exists. Use a fresh test import."
done

archive_source=$(realpath -e -- "$1") || fail "could not find the archive."
[ -f "$archive_source" ] && [ -r "${archive_source}.sha256" ] ||
    fail "provide the archive and its SHA-256 sidecar."
read -r expected_hash _ < "${archive_source}.sha256" ||
    fail "could not read the archive checksum."
[[ "$expected_hash" =~ ^[0-9a-fA-F]{64}$ ]] || fail "invalid SHA-256 checksum."

script_path=$(realpath -e -- "$0") || fail "could not locate the preparation script."
settings_directory=$(dirname -- "$script_path")
repository=$(dirname -- "$settings_directory")
toolkit=/root/fresh-test-toolkit
archive=/root/quakestrikeph-with-prediction.tar.gz
scripts=(quakestrikeph-accounts.sh quakestrikeph-config.sh quakestrikeph-install.sh
    quakestrikeph-seed.sh quakestrikeph-uninstall.sh quakestrikeph-rebuild.sh)

for script in "${scripts[@]}"
do
    bash -n "$repository/$script" || fail "invalid or missing course script: $script."
done

# Keep the cached package versions stable until the manual offline test.
systemctl disable --now apt-daily.timer apt-daily-upgrade.timer ||
    fail "could not disable the APT timers."
if systemctl is-active --quiet apt-daily.service apt-daily-upgrade.service
then
    fail "APT maintenance is still running. Wait for it to finish and retry."
fi

install -d -m 700 -- "$toolkit" || fail "could not create the toolkit directory."
for script in "${scripts[@]}"
do
    install -m 700 -- "$repository/$script" "$toolkit/$script" ||
        fail "could not copy $script."
done

echo "Copying and checking the offline archive..."
archive_copy=$(mktemp /root/.quakestrikeph-archive.XXXXXX) || fail "could not create a temporary archive."
trap 'rm -f -- "$archive_copy"' EXIT
install -m 600 -- "$archive_source" "$archive_copy" || fail "could not copy the archive."
actual_hash=$(sha256sum -- "$archive_copy") || fail "could not check the copied archive."
[ "${actual_hash%% *}" = "${expected_hash,,}" ] || fail "archive checksum mismatch."
mv -fT -- "$archive_copy" "$archive" || fail "could not save the verified archive."
trap - EXIT

# Install the existing namespace and runtime settings in this distro only.
systemd_directory=/etc/systemd/system
network_unit=quakestrikeph-rehearsal-network.service
proxy_unit=quakestrikeph-rehearsal-proxy@.service
install -m 644 -- "$settings_directory/$network_unit" "$settings_directory/$proxy_unit" \
    "$systemd_directory/" || fail "could not install the network and proxy units."
for service in docker containerd
do
    drop_ins="$systemd_directory/$service.service.d"
    install -d -m 755 -- "$drop_ins" &&
        install -m 644 -- "$settings_directory/private-network.conf" "$drop_ins/private-network.conf" &&
        install -m 644 -- "$settings_directory/$service-network.conf" "$drop_ins/runtime-network.conf" ||
        fail "could not install $service network settings."
done

# Retain the container ports. Publish this test on separate Windows ports.
bulletin_socket=quakestrikeph-rehearsal-bulletin.socket
api_socket=quakestrikeph-rehearsal-api.socket
sed 's/^ListenStream=.*/ListenStream=127.0.0.1:24321/' "$settings_directory/$bulletin_socket" \
    > "$systemd_directory/$bulletin_socket" || fail "could not install the website socket."
sed 's/^ListenStream=.*/ListenStream=127.0.0.1:23000/' "$settings_directory/$api_socket" \
    > "$systemd_directory/$api_socket" || fail "could not install the API socket."
systemctl daemon-reload || fail "could not reload the systemd settings."
systemctl enable --now "$network_unit" "$bulletin_socket" "$api_socket" ||
    fail "could not start the private network or bind ports 24321 and 23000."

namespace=/run/quakestrikeph-rehearsal.netns
shared_network=$(readlink /proc/1/ns/net) || fail "could not identify WSL's network."
private_network=$(nsenter --net="$namespace" readlink /proc/self/ns/net) ||
    fail "could not enter the test network."
[ "$shared_network" != "$private_network" ] || fail "the test network is not isolated."
for family in -4 -6
do
    default_route=$(nsenter --net="$namespace" ip "$family" route show default) ||
        fail "could not check the test network routes."
    [ -z "$default_route" ] || fail "the test network has an internet default route."
done

echo "Fresh test prepared. The six course scripts are in $toolkit."
echo "Start the timed rebuild manually with --archive $archive --config /root/fresh-test.env."

if [ "$open_shell" = true ]
then
    cd -- "$toolkit" || fail "could not enter the toolkit directory."
    echo "Opening the offline shell in $toolkit."
    exec nsenter --net="$namespace" bash
fi
