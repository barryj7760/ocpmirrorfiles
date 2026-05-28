#!/bin/bash -x

set -euo pipefail

#
# Usage:
#   ./mirror.sh /archive/path
#

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <DEST_BASE>"
    exit 1
fi

BASE_DIR="$(pwd)"
DEST_BASE="$1"

# Ensure destination exists
mkdir -p "$DEST_BASE"

# Log file
LOG_FILE="$DEST_BASE/mirror.log"

# Logging function
log() {
    local MSG="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $MSG" | tee -a "$LOG_FILE"
}

log "Starting mirror workflow"
log "BASE_DIR=$BASE_DIR"
log "DEST_BASE=$DEST_BASE"

# Build in-memory list of all .yaml files without extension
mapfile -t FILES < <(
    find "$BASE_DIR" -maxdepth 1 -type f -name "*.yaml" \
    -printf "%f\n" | sed 's/\.yaml$//'
)

# Iterate through all file names
for FILE in "${FILES[@]}"; do

    log "Processing: $FILE"

    TARGET_DIR="$BASE_DIR/$FILE"

    # Parent directory name of BASE_DIR
    #
    # Example:
    #   BASE_DIR=/data/ocp
    #   PARENT_NAME=ocp
    #
    PARENT_NAME="$(basename "$BASE_DIR")"

    # Archive destination preserving hierarchy
    #
    # Example:
    #   DEST_BASE=/archive
    #   FILE=417
    #   Result:
    #   /archive/ocp/417
    #
    DEST_DIR="$DEST_BASE/$PARENT_NAME/$FILE"

    # Create working directory
    mkdir -p "$TARGET_DIR"

    # Enter working directory
    pushd "$TARGET_DIR" > /dev/null

    SUCCESS=false

    # Retry loop
    for ATTEMPT in 1 2 3; do

        log "Running oc-mirror for $FILE (attempt $ATTEMPT)"

        if oc-mirror --v2 \
            --config "$BASE_DIR/${FILE}.yaml" \
            "file://$TARGET_DIR" \
            --cache-dir="$TARGET_DIR" \
            --image-timeout 6h; then

            SUCCESS=true
            log "oc-mirror succeeded for $FILE"
            break

        else
            log "oc-mirror failed for $FILE on attempt $ATTEMPT"

            if [[ "$ATTEMPT" -lt 3 ]]; then
                log "Retrying in 10 seconds..."
                sleep 10
            fi
        fi
    done

    # Exit current item if all retries failed
    if [[ "$SUCCESS" != true ]]; then
        log "ERROR: oc-mirror failed after 3 attempts for $FILE"
        popd > /dev/null
        continue
    fi

    # Cleanup everything except mirror tar files
    log "Cleaning directory for $FILE"

    shopt -s nullglob

    for ITEM in "$TARGET_DIR"/*; do
	BASENAME="$(basename "$ITEM")"

	if [[ ! "$BASENAME" =~ ^mirror_.*\.tar$ ]]; then
	    rm -rf "$ITEM"
	fi
    done

    shopt -u nullglob

    # Ensure destination parent exists
    mkdir -p "$(dirname "$DEST_DIR")"

    COPY_REQUIRED=true

    # Compare source and destination if destination exists
    if [[ -d "$DEST_DIR" ]]; then

        log "Comparing source and destination for $FILE"

        if rsync -rcn --delete \
            "$TARGET_DIR/" \
            "$DEST_DIR/" | grep -q .; then

            log "Differences detected for $FILE"
            COPY_REQUIRED=true

        else
            log "Destination already identical for $FILE"
            COPY_REQUIRED=false
        fi
    fi

    # Copy only if needed
    if [[ "$COPY_REQUIRED" == true ]]; then

        log "Copying $FILE to archive destination: $DEST_DIR"

        rsync -a --delete \
            "$TARGET_DIR/" \
            "$DEST_DIR/"

        log "Copy completed for $FILE"
    fi

    # Return to base directory
    popd > /dev/null

    # Remove original working directory
    log "Removing original directory for $FILE"

    rm -rf "$TARGET_DIR"

    log "Finished processing: $FILE"

done

log "All done."

