#!/usr/bin/env bash

set -euo pipefail

TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="/Users/eris/Developer/CotU_assets/at-icons/node"

if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory '$SOURCE_DIR' does not exist." >&2
    exit 1
fi

echo "Target folder: $TARGET_DIR"
echo "Source folder: $SOURCE_DIR"
echo "--------------------------------------------------------"

replaced=0
skipped=0

while IFS= read -r -d '' target_file; do
    filename="$(basename "$target_file")"
    
    # Check flat in SOURCE_DIR first; if not found, search subfolders
    if [ -f "$SOURCE_DIR/$filename" ]; then
        source_file="$SOURCE_DIR/$filename"
    else
        source_file="$(find "$SOURCE_DIR" -type f -name "$filename" -print -quit 2>/dev/null)"
    fi

    if [ -n "$source_file" ] && [ -f "$source_file" ]; then
        cp "$source_file" "$target_file"
        echo "Replaced: $filename"
        replaced=$((replaced + 1))
    else
        echo "Skipped (not found in source): $filename" >&2
        skipped=$((skipped + 1))
    fi
done < <(find "$TARGET_DIR" -type f -iname "*.svg" -print0)

echo "--------------------------------------------------------"
echo "Finished. Replaced: $replaced | Skipped: $skipped"