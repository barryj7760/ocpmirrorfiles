#!/bin/bash

set -euo pipefail

BASE_DIR="$(pwd)"

# Build in-memory list of all .yaml files without extension
mapfile -t FILES < <(
    find "$BASE_DIR" -maxdepth 1 -type f -name "*.yaml" \
    -printf "%f\n" | sed 's/\.yaml$//'
)

# Iterate through all file names
for FILE in "${FILES[@]}"; do
    echo "Processing: $FILE"

    TARGET_DIR="$BASE_DIR/$FILE"

    # Create directory
    mkdir -p "$TARGET_DIR"

    # Enter directory
    pushd "$TARGET_DIR" > /dev/null

    # Run oc-mirror
    oc-mirror --v2 \
        --config "$BASE_DIR/${FILE}.yaml" \
        "file://$TARGET_DIR" \
	--cache-dir=$TARGET_DIR \
        --image-timeout 6h

    # Return to base directory
    popd > /dev/null

    echo "Finished: $FILE"
done

echo "All done."
