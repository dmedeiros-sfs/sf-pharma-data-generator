#!/bin/bash
# media.sh - Dependency-free media helpers for dataset file templates.

MEDIA_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pad_media_file() {
    local filepath=$1
    local size_kb=$2
    local target_bytes=$((size_kb * 1024))
    local current_bytes
    current_bytes=$(wc -c < "$filepath")

    # The embedded files are valid JPEG, PNG, and MP4 containers. 
    # Padding preserves the existing size distribution with random data after each format's end marker/atoms, which readers ignore.
    if [ "$current_bytes" -lt "$target_bytes" ]; then
        dd if=/dev/urandom bs=1 count=$((target_bytes - current_bytes)) status=none >> "$filepath" || return 1
    fi
}

create_media_file() {
    local filepath=$1
    local size_kb=$2
    local template

    case "${filepath,,}" in
        *.jpg|*.jpeg) template="$MEDIA_LIB_DIR/assets/media-template.jpg.b64" ;;
        *.png)        template="$MEDIA_LIB_DIR/assets/media-template.png.b64" ;;
        *.mp4)        template="$MEDIA_LIB_DIR/assets/media-template.mp4.b64" ;;
        *)            return 2 ;;
    esac

    # The JPEG and PNG templates contain fixed EXIF metadata. 
    # The MP4 template contains fixed QuickTime title/comment metadata. No media package is required at generation time.
    base64 -d "$template" > "$filepath" || return 1
    pad_media_file "$filepath" "$size_kb"
}
