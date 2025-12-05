#!/bin/bash

# This script copies dSYM files from the build directory to the archive directory
# to fix "Upload Symbols Failed" warnings for SPM binary frameworks (e.g. Firebase).

# Log file for debugging
LOG_FILE="/tmp/deenbuddy_dsym_copy.log"

log() {
    echo "$(date): $1" >> "$LOG_FILE"
}

log "Starting dSYM copy script..."

# Determine Source
SRC_DIR="$BUILT_PRODUCTS_DIR"
if [ -z "$SRC_DIR" ]; then
    log "Error: BUILT_PRODUCTS_DIR is not set."
    log "Make sure to select 'Provide build settings from' -> [Your App Target] in the Scheme Post-actions."
    exit 1
fi

# Determine Destination
if [ -n "$ARCHIVE_PATH" ]; then
    # Running as Archive Post-action
    DEST_DIR="$ARCHIVE_PATH/dSYMs"
elif [ -n "$ARCHIVE_DSYMS_PATH" ]; then
    # Running as Build Phase (if supported)
    DEST_DIR="$ARCHIVE_DSYMS_PATH"
else
    log "Error: Could not determine destination. ARCHIVE_PATH or ARCHIVE_DSYMS_PATH is missing."
    exit 1
fi

log "Initial Source: $SRC_DIR"
log "Destination: $DEST_DIR"

# Ensure destination exists
mkdir -p "$DEST_DIR"

# Function to copy dSYMs from a directory
copy_dsyms_from() {
    local search_dir="$1"
    log "Searching for dSYMs in: $search_dir"
    
    if [ ! -d "$search_dir" ]; then
        log "Directory not found: $search_dir"
        return
    fi

    local count=0
    # Find dSYMs, following symlinks (-L)
    while IFS= read -r -d '' dsym; do
        dsym_name=$(basename "$dsym")
        
        # Skip the main app's dSYM
        if [ "$dsym_name" == "${PRODUCT_NAME}.app.dSYM" ]; then
            continue
        fi

        target_path="$DEST_DIR/$dsym_name"

        if [ ! -d "$target_path" ]; then
            log "Found $dsym_name in $search_dir. Copying..."
            cp -r "$dsym" "$DEST_DIR/"
            if [ $? -eq 0 ]; then
                log "Successfully copied $dsym_name"
                ((count++))
            else
                log "Failed to copy $dsym_name"
            fi
        else
            log "$dsym_name already exists in archive. Skipping."
        fi
    done < <(find -L "$search_dir" -name "*.dSYM" -print0)
    
    log "Found and processed $count dSYMs in $search_dir"
}

# 1. Search in BUILT_PRODUCTS_DIR (Standard location)
copy_dsyms_from "$SRC_DIR"

# 2. Search in SourcePackages (SPM location)
DERIVED_DATA_PROJ_DIR=""

# Prefer Xcode-provided paths over hardcoded traversal
if [ -n "$BUILD_DIR" ]; then
    DERIVED_DATA_PROJ_DIR=$(cd "$BUILD_DIR/.." 2>/dev/null && pwd)
elif [ -n "$BUILT_PRODUCTS_DIR" ]; then
    DERIVED_DATA_PROJ_DIR=$(cd "$BUILT_PRODUCTS_DIR/../../.." 2>/dev/null && pwd)
fi

# Fallback: derive from source root if available
if [ -z "$DERIVED_DATA_PROJ_DIR" ] && [ -n "${SRCROOT:-$SOURCE_ROOT}" ]; then
    DERIVED_DATA_PROJ_DIR=$(cd "${SRCROOT:-$SOURCE_ROOT}/.." 2>/dev/null && pwd)
fi

# Validate derived data directory
if [ -n "$DERIVED_DATA_PROJ_DIR" ] && [ ! -d "$DERIVED_DATA_PROJ_DIR" ]; then
    log "Computed DerivedData directory does not exist: $DERIVED_DATA_PROJ_DIR"
    DERIVED_DATA_PROJ_DIR=""
fi

if [ -z "$DERIVED_DATA_PROJ_DIR" ]; then
    log "Could not resolve DerivedData project directory from build settings."
fi

SOURCE_PACKAGES_DIR=""
if [ -n "$DERIVED_DATA_PROJ_DIR" ]; then
    SOURCE_PACKAGES_DIR="$DERIVED_DATA_PROJ_DIR/SourcePackages"
fi

if [ -z "$SOURCE_PACKAGES_DIR" ] || [ ! -d "$SOURCE_PACKAGES_DIR" ]; then
    log "Could not locate SourcePackages directory at expected path: ${SOURCE_PACKAGES_DIR:-<unset>}"
    # Try searching for it starting from derived data or source root as a safe fallback
    SEARCH_ROOT="${DERIVED_DATA_PROJ_DIR:-${SRCROOT:-${SOURCE_ROOT:-$PWD}}}"
    POSSIBLE_SOURCE_PACKAGES=$(find "$SEARCH_ROOT" -maxdepth 5 -type d -name "SourcePackages" | head -n 1)
    if [ -n "$POSSIBLE_SOURCE_PACKAGES" ]; then
         log "Found SourcePackages via search: $POSSIBLE_SOURCE_PACKAGES"
         SOURCE_PACKAGES_DIR="$POSSIBLE_SOURCE_PACKAGES"
    fi
fi

if [ -n "$SOURCE_PACKAGES_DIR" ] && [ -d "$SOURCE_PACKAGES_DIR" ]; then
    log "Found SourcePackages dir: $SOURCE_PACKAGES_DIR"
    
    # DIAGNOSTIC: Check content of FirebaseAnalytics.xcframework to see if dSYMs are inside
    FIREBASE_FRAMEWORK=$(find -L "$SOURCE_PACKAGES_DIR" -name "FirebaseAnalytics.xcframework" -print -quit)
    if [ -n "$FIREBASE_FRAMEWORK" ]; then
        log "--- DIAGNOSTIC: Content of FirebaseAnalytics.xcframework ---"
        ls -R "$FIREBASE_FRAMEWORK" >> "$LOG_FILE"
        log "--- END DIAGNOSTIC ---"
    else
        log "WARNING: Could not find FirebaseAnalytics.xcframework in SourcePackages"
    fi
    
    copy_dsyms_from "$SOURCE_PACKAGES_DIR"
else
    log "CRITICAL: SourcePackages directory not found."
fi

log "dSYM copy process complete."
