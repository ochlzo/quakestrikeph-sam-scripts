#!/bin/bash
# AI-assisted integration test. Creates/reuses the REAL dedicated service account,
# but applies file permissions only to temporary fixtures directly under /srv.
# Run as root inside the disposable course environment, after reviewing the script.
set -eu
repository=$(cd -- "$(dirname -- "$0")/.." && pwd)
script="$repository/quakestrikeph-accounts.sh"
[ "$EUID" -eq 0 ] || { echo 'Run as root in the demo environment.'; exit 1; }
work=$(mktemp -d /srv/quakestrikeph-permissions-test.XXXXXX)
outside=$(mktemp -d /tmp/quakestrikeph-permissions-outside.XXXXXX)
trap 'rm -rf -- "$work" "$outside"' EXIT

expect_failure()
{
    if bash "$script" --directory "$1" > "$outside/output" 2>&1
    then
        echo "FAIL: accepted unsafe directory $1"
        exit 1
    fi
    grep -q "$2" "$outside/output"
}

expect_failure / 'dedicated /srv/NAME'
expect_failure /srv 'dedicated /srv/NAME'
expect_failure /srv/.. 'dot segments or symlink'
touch "$work/unrelated"
expect_failure "$work" 'nonempty directory is not an installation'
rm "$work/unrelated"

# Before installation, only the account and empty directory are needed.
bash "$script" --directory "$work"
first_identity=$(id quakestrikeph)
bash "$script" --directory "$work"
[ "$(id quakestrikeph)" = "$first_identity" ]

mkdir -p "$work/infrastructure" "$work/apps/quakestrikeph-bulletin" "$work/bootstrap-snapshots/source-snapshots"
touch "$work/infrastructure/compose.checkoff.yml" "$work/apps/quakestrikeph-bulletin/package.json"
printf 'fake-test-only\n' > "$work/.env"
touch "$work/code.txt" "$work/helper.sh" "$work/bootstrap-snapshots/source-snapshots/test.json"
chmod 755 "$work/helper.sh"
touch "$outside/unchanged"
chmod 644 "$outside/unchanged"
ln -s "$outside/unchanged" "$work/linked"
expect_failure "$work" 'review linked file'
[ "$(stat -c '%a' "$outside/unchanged")" = 644 ]
rm "$work/linked"

bash "$script" --directory "$work"
bash "$script" --directory "$work"
[ "$(id quakestrikeph)" = "$first_identity" ]
[ "$(stat -c '%a %U:%G' "$work/.env")" = '600 root:root' ]
[ "$(stat -c '%a %U:%G' "$work/code.txt")" = '640 root:quakestrikeph' ]
[ "$(stat -c '%a' "$work/helper.sh")" = 750 ]
[ "$(stat -c '%a %U:%G' "$work/bootstrap-snapshots")" = '700 quakestrikeph:quakestrikeph' ]
[ "$(stat -c '%a' "$work/bootstrap-snapshots/source-snapshots/test.json")" = 600 ]
runuser -u quakestrikeph -- test -r "$work/code.txt"
runuser -u quakestrikeph -- test ! -w "$work/code.txt"
runuser -u quakestrikeph -- test ! -r "$work/.env"
runuser -u quakestrikeph -- touch "$work/bootstrap-snapshots/write-test"
runuser -u nobody -- test ! -r "$work/code.txt"
echo 'PASS: real service identity, repeat runs, private configuration, read-only code, writable evidence, unsafe-path/link rejection.'
