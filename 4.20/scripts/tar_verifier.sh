#!/usr/bin/env bash

set -u

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

ROOT="$1"

if [[ ! -d "$ROOT" ]]; then
    echo "Error: '$ROOT' is not a directory."
    exit 1
fi

declare -A bad_dirs
bad_count=0
total=0

echo "Scanning for tar archives under: $ROOT"
echo

while IFS= read -r -d '' tarfile; do
    ((total++))

    printf "Checking: %s\n" "$tarfile"

    if ! tar -tf "$tarfile" >/dev/null 2>&1; then
        dir=$(dirname "$tarfile")
        bad_dirs["$dir"]+=$'\n'"    $(basename "$tarfile")"
        ((bad_count++))
    fi
done < <(find "$ROOT" -type f -name "*.tar" -print0)

echo
echo "========================================"
echo "Scan complete"
echo "Archives checked : $total"
echo "Faulty archives  : $bad_count"
echo "========================================"

if (( bad_count == 0 )); then
    echo "No faulty tar archives found."
    exit 0
fi

echo
echo "Directories containing faulty tar files:"
echo

for dir in "${!bad_dirs[@]}"; do
    echo "$dir"
    printf "%s\n" "${bad_dirs[$dir]}"
    echo
done

exit 1
