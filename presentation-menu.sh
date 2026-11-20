#!/bin/bash

# Rehearsal convenience menu; the six course scripts remain separate.
# Usage: bash presentation-menu.sh [--help]
# AI assistance: ChatGPT helped write and verify this presentation helper.

if [ "${1:-}" = --help ] && [ "$#" -eq 1 ]
then
    echo "Usage: bash presentation-menu.sh [--help]"
    echo "Run one selected course script in QuakeStrikePH-Rehearsal as root."
    echo "Uses /root/rehearsal.env and /root/quakestrikeph-with-prediction.tar.gz."
    echo "Installation also reapplies permissions. Uninstall previews before confirmation."
    echo "Example: wsl -d QuakeStrikePH-Rehearsal -u root -- bash /root/rehearsal-toolkit/presentation-menu.sh"
    exit 0
fi

[ "$#" -eq 0 ] || { echo "Unknown option. Use --help." >&2; exit 1; }
[ "${WSL_DISTRO_NAME:-}" = QuakeStrikePH-Rehearsal ] || { echo "Use QuakeStrikePH-Rehearsal only." >&2; exit 1; }
[ "$EUID" -eq 0 ] || { echo "Run as root." >&2; exit 1; }
script_path=$(realpath -e -- "$0") || exit 1
script_directory=$(dirname -- "$script_path") || exit 1
archive=/root/quakestrikeph-with-prediction.tar.gz
config=/root/rehearsal.env

run_script()
{
    local script_name="$1"
    local network_pid private_network shared_network
    shift
    network_pid=$(systemctl show -p MainPID --value quakestrikeph-rehearsal-network.service) || return 1
    [[ "$network_pid" =~ ^[1-9][0-9]*$ ]] || { echo "The rehearsal network is not running." >&2; return 1; }
    private_network=$(readlink "/proc/$network_pid/ns/net") || return 1
    shared_network=$(readlink /proc/1/ns/net) || return 1
    [ "$private_network" != "$shared_network" ] || { echo "The rehearsal network is not isolated." >&2; return 1; }
    echo "Running $script_name..."
    nsenter -t "$network_pid" -n bash "$script_directory/$script_name" "$@"
}

while true
do
    echo ""
    echo "QuakeStrikePH-Rehearsal - select one script:"
    echo "1. Full rebuild"
    echo "2. Accounts and permissions"
    echo "3. Configuration"
    echo "4. Installation (then final permissions)"
    echo "5. Seed and verify forecast"
    echo "6. Clean uninstall (preview first)"
    echo "0. Exit"
    read -r -p "Choice: " choice || exit 0

    case "$choice" in
        1) run_script quakestrikeph-rebuild.sh --archive "$archive" --config "$config" ;;
        2) run_script quakestrikeph-accounts.sh ;;
        3) run_script quakestrikeph-config.sh --output "$config" ;;
        4)
            run_script quakestrikeph-install.sh --archive "$archive" --config "$config" &&
                run_script quakestrikeph-accounts.sh
            ;;
        5) run_script quakestrikeph-seed.sh ;;
        6)
            run_script quakestrikeph-uninstall.sh
            result=$?
            echo "Preview exit code: $result"
            [ "$result" -eq 0 ] || exit "$result"
            read -r -p "Type REMOVE to delete the rehearsal application and database, or Enter to cancel: " confirmation || exit 0
            if [ "$confirmation" != REMOVE ]
            then
                echo "Removal cancelled."
                continue
            fi
            run_script quakestrikeph-uninstall.sh --confirm
            ;;
        0) exit 0 ;;
        *) echo "Choose a number from 0 to 6."; continue ;;
    esac
    result=$?
    echo "Exit code: $result"
    if [ "$result" -ne 0 ]
    then
        echo "Stopped after failure. Review the message above before retrying." >&2
        exit "$result"
    fi
    echo "Completed. Website: http://127.0.0.1:14321 (unavailable after uninstall)."
done
