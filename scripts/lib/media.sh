#!/bin/bash
# media.sh - Valid media generation helpers for dataset file templates.

require_media_tools() {
    if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v exiftool >/dev/null 2>&1; then
        echo "Error: .jpg and .mp4 templates require ffmpeg and exiftool. Install with: sudo apt-get install ffmpeg libimage-exiftool-perl" >&2
        return 1
    fi
}

pad_media_file() {
    local filepath=$1
    local size_kb=$2
    local target_bytes=$((size_kb * 1024))
    local current_bytes
    current_bytes=$(wc -c < "$filepath")

    # Padding preserves the existing size distribution. 
    # JPEG and MP4 readers ignore data following their respective end markers/atoms.
    if [ "$current_bytes" -lt "$target_bytes" ]; then
        truncate -s "$target_bytes" "$filepath"
    fi
}

create_jpeg_file() {
    local filepath=$1
    local size_kb=$2
    local captured_at
    captured_at=$(date '+%Y:%m:%d %H:%M:%S')

    require_media_tools || return 1
    ffmpeg -hide_banner -loglevel error -y \
        -f lavfi -i 'testsrc2=size=640x480:rate=1' -frames:v 1 -q:v 3 "$filepath" || return 1
    exiftool -overwrite_original \
        -DateTimeOriginal="$captured_at" -CreateDate="$captured_at" -ModifyDate="$captured_at" \
        -Make='Starfish Lab' -Model='Dataset Camera' -Software='sf-pharma-data-generator' \
        "$filepath" >/dev/null || return 1
    pad_media_file "$filepath" "$size_kb"
}

create_mp4_file() {
    local filepath=$1
    local size_kb=$2
    local recorded_at
    local title
    recorded_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    title=$(basename "${filepath%.*}")

    require_media_tools || return 1
    ffmpeg -hide_banner -loglevel error -y \
        -f lavfi -i 'testsrc2=size=320x240:rate=15' -t 1 \
        -c:v libx264 -preset ultrafast -crf 28 -pix_fmt yuv420p -movflags +faststart \
        -metadata title="$title" -metadata comment='Generated lab environment demo media' \
        -metadata creation_time="$recorded_at" "$filepath" || return 1
    exiftool -overwrite_original \
        -QuickTime:CreateDate="$recorded_at" -QuickTime:ModifyDate="$recorded_at" \
        -QuickTime:Title="$title" -QuickTime:Comment='Generated lab environment demo media' \
        "$filepath" >/dev/null || return 1
    pad_media_file "$filepath" "$size_kb"
}

create_media_file() {
    local filepath=$1
    local size_kb=$2

    case "${filepath,,}" in
        *.jpg|*.jpeg) create_jpeg_file "$filepath" "$size_kb" ;;
        *.mp4)        create_mp4_file "$filepath" "$size_kb" ;;
        *)            return 2 ;;
    esac
}
