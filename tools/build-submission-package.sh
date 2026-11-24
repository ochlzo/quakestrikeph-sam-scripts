#!/bin/bash

# Build the Section 7.1 IT 123 submission archive in outputs/.
# Authors: Armenta, Buergo, Candelaria, Pispis
# Usage: bash tools/build-submission-package.sh [--output-dir PATH]
# AI assistance: GPT 6.2 Sol (Codex) and Gemini 4 Neon (Antigravity) assisted with edge-case checks, refactoring, and review.
# Note: This is a local packaging helper, not one of the six submitted Option 1C scripts.

script_dir=$(cd "$(dirname "$0")" && pwd)
repo_dir=$(cd "$script_dir/.." && pwd)
output_dir="$repo_dir/outputs"
package_name="IT123_FP_4B_G10_QuakeStrikePH_1C"

fail()
{
    echo "Package build failed: $*" >&2
    exit 1
}

while [ "$#" -gt 0 ]
do
    if [ "$1" = "--help" ]
    then
        echo "Usage: bash tools/build-submission-package.sh [--output-dir PATH]"
        echo "Assemble ${package_name}.tar.gz containing only README.pdf, scripts/, man/, and samples/."
        echo ""
        echo "Options:"
        echo "  --output-dir PATH  Folder where the .tar.gz archive is written. Default: ./outputs"
        echo "  --help             Show this help message and exit."
        echo ""
        echo "Example:"
        echo "  bash tools/build-submission-package.sh --output-dir ./outputs"
        exit 0

    elif [ "$1" = "--output-dir" ]
    then
        if [ "$#" -lt 2 ] || [ -z "$2" ]
        then
            fail "--output-dir requires a path."
        fi
        output_dir="$2"
        shift 2

    else
        fail "unknown option '$1'. Use --help."
    fi
done

for required_command in tar gzip mktemp cp chmod mkdir
do
    if ! command -v "$required_command" > /dev/null
    then
        fail "$required_command is required."
    fi
done

required_scripts=(
    quakestrikeph-accounts.sh
    quakestrikeph-config.sh
    quakestrikeph-install.sh
    quakestrikeph-restore.sh
    quakestrikeph-uninstall.sh
    quakestrikeph-rebuild.sh
)

required_samples=(
    quakestrikeph-accounts-sample.txt
    quakestrikeph-config-sample.txt
    quakestrikeph-install-sample.txt
    quakestrikeph-restore-sample.txt
    quakestrikeph-uninstall-sample.txt
    quakestrikeph-rebuild-sample.txt
)

[ -f "$repo_dir/README.pdf" ] || fail "missing README.pdf in $repo_dir."
[ -f "$repo_dir/man/quakestrikeph-toolkit.8" ] || fail "missing man/quakestrikeph-toolkit.8."

for script_file in "${required_scripts[@]}"
do
    [ -f "$repo_dir/$script_file" ] || fail "missing script: $script_file"
done

for sample_file in "${required_samples[@]}"
do
    [ -f "$repo_dir/samples/$sample_file" ] || fail "missing sample: samples/$sample_file"
done

staging_dir=$(mktemp -d) || fail "could not create temporary staging directory."
trap 'rm -rf -- "$staging_dir"' EXIT

pkg_root="$staging_dir/$package_name"
mkdir -p "$pkg_root/scripts" "$pkg_root/man" "$pkg_root/samples" \
    || fail "could not create package folders."

cp "$repo_dir/README.pdf" "$pkg_root/README.pdf" || fail "could not copy README.pdf."
chmod 644 "$pkg_root/README.pdf"

cp "$repo_dir/man/quakestrikeph-toolkit.8" "$pkg_root/man/quakestrikeph-toolkit.8" \
    || fail "could not copy manual page."
chmod 644 "$pkg_root/man/quakestrikeph-toolkit.8"

for script_file in "${required_scripts[@]}"
do
    cp "$repo_dir/$script_file" "$pkg_root/scripts/$script_file" \
        || fail "could not copy $script_file."
    chmod 755 "$pkg_root/scripts/$script_file"
done

for sample_file in "${required_samples[@]}"
do
    cp "$repo_dir/samples/$sample_file" "$pkg_root/samples/$sample_file" \
        || fail "could not copy samples/$sample_file."
    chmod 644 "$pkg_root/samples/$sample_file"
done

mkdir -p "$output_dir" || fail "could not create $output_dir."
archive_path="$output_dir/${package_name}.tar.gz"

tar -czf "$archive_path" -C "$staging_dir" "$package_name" \
    || fail "could not create $archive_path."

gzip -t "$archive_path" || fail "created archive failed gzip integrity check."
tar -tzf "$archive_path" > /dev/null || fail "created archive failed tar listing check."

echo "Submission package created: $archive_path"
echo "Archive contents:"
tar -tzvf "$archive_path"
exit 0
