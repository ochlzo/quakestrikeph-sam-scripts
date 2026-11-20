#!/bin/bash
# AI-assisted simulation. Docker, account deletion, and filesystem removal are
# intercepted. Only the harness's own temporary /srv fixture may actually be deleted.
# No command is forwarded to real Docker, userdel, or groupdel.
set -eu
repository=$(cd -- "$(dirname -- "$0")/.." && pwd)
script="$repository/quakestrikeph-uninstall.sh"
[ "$EUID" -eq 0 ] || { echo 'Run as root for temporary /srv test folders.'; exit 1; }
app=$(mktemp -d /srv/quakestrikeph-uninstall-test.XXXXXX)
work=$(mktemp -d)
trap '/bin/rm -rf -- "$app" "$work"' EXIT
mkdir "$work/bin"
export TEST_APP="$app" TEST_STATE="$work/state" TEST_LOG="$work/actions"
export PATH="$work/bin:$PATH"
printf 'unrelated file must survive\n' > "$work/unrelated"

cat > "$work/bin/docker" <<'SH'
#!/bin/bash
set -eu
[ "$1" = --host ] && [ "$2" = unix:///var/run/docker.sock ] || exit 90
shift 2
case "$1 ${2:-}" in
    'ps -aq'|'volume ls'|'network ls')
        [[ "$*" == *'label=com.docker.compose.project=quakestrikeph-sam'* ]] || exit 90
        case "$1" in ps) file=containers;; volume) file=volumes;; network) file=networks;; esac
        [ ! -f "$TEST_STATE/$file" ] || cat "$TEST_STATE/$file"
        ;;
    'inspect --format')
        if [ -f "$TEST_STATE/wrong-directory" ]; then echo /srv/other-app/infrastructure; else echo "$TEST_APP/infrastructure"; fi
        ;;
    'stop c11111111111')
        echo 'stop container' >> "$TEST_LOG"
        ;;
    'rm --volumes')
        [ "$3" = c11111111111 ] || exit 90
        echo 'remove container' >> "$TEST_LOG"
        /bin/rm -f "$TEST_STATE/containers"
        ;;
    'volume rm')
        echo "remove volume $3" >> "$TEST_LOG"
        [ ! -f "$TEST_STATE/volume-failure" ] || exit 42
        sed -i "/^$3$/d" "$TEST_STATE/volumes"
        ;;
    'network rm')
        [ "$3" = a11111111111 ] || exit 90
        echo 'remove network' >> "$TEST_LOG"
        /bin/rm -f "$TEST_STATE/networks"
        ;;
    *)
        if [ "$1" = info ]; then [ ! -f "$TEST_STATE/daemon-failure" ]; exit $?; fi
        echo 'Unexpected simulated Docker call.' >&2
        exit 90
        ;;
esac
SH
cat > "$work/bin/getent" <<'SH'
#!/bin/bash
case "$1" in
    passwd)
        [ -f "$TEST_STATE/user" ] || exit 2
        if [ -f "$TEST_STATE/wrong-user" ]; then uid=12345; else uid=10001; fi
        printf 'quakestrikeph:x:%s:10001:QuakeStrikePH container worker:/nonexistent:/usr/sbin/nologin\n' "$uid"
        ;;
    group)
        [ -f "$TEST_STATE/group" ] || exit 2
        echo 'quakestrikeph:x:10001:'
        ;;
    *) exit 90;;
esac
SH
printf '#!/bin/bash\necho 10001\n' > "$work/bin/id"
printf '#!/bin/bash\necho "quakestrikeph L 2026-11-18 0 99999 7 -1"\n' > "$work/bin/passwd"
cat > "$work/bin/findmnt" <<'SH'
#!/bin/bash
echo /
if [ -f "$TEST_STATE/mounted" ]; then echo "$TEST_APP/mounted"; fi
SH
for command_name in userdel groupdel
do
    cat > "$work/bin/$command_name" <<'SH'
#!/bin/bash
[ "$#" -eq 1 ] && [ "$1" = quakestrikeph ] || exit 90
command_name=${0##*/}
echo "$command_name" >> "$TEST_LOG"
if [ "$command_name" = userdel ]; then /bin/rm -f "$TEST_STATE/user"; else /bin/rm -f "$TEST_STATE/group"; fi
SH
done
cat > "$work/bin/rm" <<'SH'
#!/bin/bash
[ "$*" = "-rf --one-file-system --preserve-root=all -- $TEST_APP" ] || exit 90
[[ "$TEST_APP" == /srv/quakestrikeph-uninstall-test.* ]] || exit 90
echo 'remove test directory' >> "$TEST_LOG"
/bin/rm -rf -- "$TEST_APP"
SH
chmod +x "$work/bin/"*
for command_name in docker userdel groupdel rm getent
do
    [ "$(command -v "$command_name")" = "$work/bin/$command_name" ]
done

new_fixture()
{
    /bin/rm -rf -- "$app" "$TEST_STATE"
    mkdir -p "$app/infrastructure" "$app/apps/quakestrikeph-bulletin" "$TEST_STATE"
    touch "$app/infrastructure/compose.checkoff.yml" "$app/apps/quakestrikeph-bulletin/package.json"
    touch "$TEST_STATE/user" "$TEST_STATE/group"
    echo c11111111111 > "$TEST_STATE/containers"
    printf 'quakestrikeph-sam_postgres_data\nquakestrikeph-sam_redis_data\n' > "$TEST_STATE/volumes"
    echo a11111111111 > "$TEST_STATE/networks"
    : > "$TEST_LOG"
}

new_fixture
bash "$script" --directory "$app" > "$work/output"
test ! -s "$TEST_LOG"
test -d "$app"
grep -q 'Preview only' "$work/output"
bash "$script" --directory "$app" --confirm > "$work/output"
test ! -e "$app"
test ! -e "$TEST_STATE/user"
test ! -e "$TEST_STATE/group"
grep -q 'Uninstall successful' "$work/output"
cp "$TEST_LOG" "$work/first-actions"
bash "$script" --directory "$app" --confirm > "$work/output"
cmp -s "$TEST_LOG" "$work/first-actions"

for scenario in wrong-directory wrong-user mounted daemon-failure unexpected-volume
do
    new_fixture
    if [ "$scenario" = unexpected-volume ]; then echo unrelated_volume >> "$TEST_STATE/volumes"; else touch "$TEST_STATE/$scenario"; fi
    if bash "$script" --directory "$app" --confirm > "$work/output" 2>&1
    then
        echo "FAIL: unsafe scenario accepted: $scenario"
        exit 1
    fi
    test ! -s "$TEST_LOG"
    test -d "$app"
done

new_fixture
if bash "$script" --directory / --confirm > "$work/output" 2>&1; then exit 1; fi
test ! -s "$TEST_LOG"
touch "$TEST_STATE/volume-failure"
if bash "$script" --directory "$app" --confirm > "$work/output" 2>&1; then exit 1; fi
test -d "$app"
test -f "$TEST_STATE/user"
! grep -q 'remove test directory\|userdel\|groupdel' "$TEST_LOG"
/bin/rm "$TEST_STATE/volume-failure"
bash "$script" --directory "$app" --confirm > "$work/output"
test ! -e "$app"
test -f "$work/unrelated"
echo 'PASS: simulated preview, removal, repeat run, ownership/path guards, failed removal and retry.'
echo 'No real Docker or service-account deletion commands were executed.'
