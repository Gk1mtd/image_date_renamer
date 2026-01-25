#!/bin/bash

# Script to set video metadata creation dates from filenames
# Supports video filenames with date patterns and updates metadata accordingly

#####################################
# Dependency checks
#####################################

echo "[*] Checking dependencies..."
command -v zenity >/dev/null || { echo "[!] zenity is missing"; exit 1; }
command -v exiftool >/dev/null || { echo "[!] exiftool is missing"; exit 1; }
echo "[✓] All dependencies found"

#####################################
# Configuration
#####################################

SUPPORTED_EXTENSIONS="mp4|m4v|mov|avi|mkv|flv|wmv|webm"

#####################################
# Helpers
#####################################

chooseFolder() {
  echo "[*] Showing folder selection dialog..." >&2
  local videos_folder=$(zenity \
    --file-selection \
    --directory \
    --title="Select Videos Folder")

  [[ -z "$videos_folder" ]] && exit 0
  echo "[✓] Folder selected: $videos_folder" >&2
  echo "$videos_folder"
}

isSupported() {
  [[ "$1" =~ \.($SUPPORTED_EXTENSIONS)$ ]]
}

toExifDate() {
  # Convert YYYY-MM-DD HH:MM:SS to YYYY:MM:DD HH:MM:SS
  echo "${1//-/:}"
}

#####################################
# Date extraction from filename
#####################################

extractDateFromFilename() {
  local filename="$1"

  # Pattern: YYYYMMDD_HHMMSS (e.g., 20210411_102628)
  if [[ "$filename" =~ ([0-9]{8})[_-]([0-9]{6}) ]]; then
    echo "${BASH_REMATCH[1]:0:4}-${BASH_REMATCH[1]:4:2}-${BASH_REMATCH[1]:6:2} \
${BASH_REMATCH[2]:0:2}:${BASH_REMATCH[2]:2:2}:${BASH_REMATCH[2]:4:2}"
  # Pattern: YYYYMMDD HHMMSS with spaces (e.g., Photo 20160110 155600)
  elif [[ "$filename" =~ ([0-9]{8})\ ([0-9]{6}) ]]; then
    echo "${BASH_REMATCH[1]:0:4}-${BASH_REMATCH[1]:4:2}-${BASH_REMATCH[1]:6:2} \
${BASH_REMATCH[2]:0:2}:${BASH_REMATCH[2]:2:2}:${BASH_REMATCH[2]:4:2}"
  # Pattern: YYYY-MM-DD-HHMMSS (e.g., signal-2021-08-08-205245)
  elif [[ "$filename" =~ ([0-9]{4})-([0-9]{2})-([0-9]{2})-([0-9]{2})([0-9]{2})([0-9]{2}) ]]; then
    echo "${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${BASH_REMATCH[3]} \
${BASH_REMATCH[4]}:${BASH_REMATCH[5]}:${BASH_REMATCH[6]}"
  # Pattern: YYYY-MM-DD_HHMMSS (e.g., 2021-08-08_205245)
  elif [[ "$filename" =~ ([0-9]{4})-([0-9]{2})-([0-9]{2})_([0-9]{2})([0-9]{2})([0-9]{2}) ]]; then
    echo "${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${BASH_REMATCH[3]} \
${BASH_REMATCH[4]}:${BASH_REMATCH[5]}:${BASH_REMATCH[6]}"
  # Pattern: YYYY-MM-DD_HH-MM-SS (e.g., 2021-08-08_20-52-45)
  elif [[ "$filename" =~ ([0-9]{4})-([0-9]{2})-([0-9]{2})_([0-9]{2})-([0-9]{2})-([0-9]{2}) ]]; then
    echo "${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${BASH_REMATCH[3]} \
${BASH_REMATCH[4]}:${BASH_REMATCH[5]}:${BASH_REMATCH[6]}"
  # Pattern: *-YYYY-MM-DD-HH-MM-SS* (e.g., signal-2024-05-04-09-23-20-699-2)
  elif [[ "$filename" =~ ([0-9]{4})-([0-9]{2})-([0-9]{2})-([0-9]{2})-([0-9]{2})-([0-9]{2}) ]]; then
    echo "${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${BASH_REMATCH[3]} \
${BASH_REMATCH[4]}:${BASH_REMATCH[5]}:${BASH_REMATCH[6]}"
  # Pattern: IMG-YYYYMMDD-* (e.g., IMG-20210104-WA0019)
  elif [[ "$filename" =~ IMG-([0-9]{8})-.*\. ]]; then
    local datestr="${BASH_REMATCH[1]}"
    echo "${datestr:0:4}-${datestr:4:2}-${datestr:6:2} 12:00:00"
  # Pattern: *-YYYYMMDD-* (e.g., Vid-20160930-Wa0005)
  elif [[ "$filename" =~ -([0-9]{8})-.*\. ]]; then
    local datestr="${BASH_REMATCH[1]}"
    echo "${datestr:0:4}-${datestr:4:2}-${datestr:6:2} 12:00:00"
  # Pattern: YYYYMMDD (at start, e.g., 20191005 Taufe 5-39.mp4)
  elif [[ "$filename" =~ ^([0-9]{8}) ]]; then
    local datestr="${BASH_REMATCH[1]}"
    echo "${datestr:0:4}-${datestr:4:2}-${datestr:6:2} 12:00:00"
  # Pattern: YYYY_MM_DD_HHMMSS (e.g., 2021_08_08_205245)
  elif [[ "$filename" =~ ([0-9]{4})_([0-9]{2})_([0-9]{2})_([0-9]{2})([0-9]{2})([0-9]{2}) ]]; then
    echo "${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${BASH_REMATCH[3]} \
${BASH_REMATCH[4]}:${BASH_REMATCH[5]}:${BASH_REMATCH[6]}"
  # Pattern: YYYY-MM-DD HH.MM.SS (e.g., 2016-03-05 12.26.24)
  elif [[ "$filename" =~ ([0-9]{4})-([0-9]{2})-([0-9]{2})\ ([0-9]{2})\.([0-9]{2})\.([0-9]{2}) ]]; then
    echo "${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${BASH_REMATCH[3]} \
${BASH_REMATCH[4]}:${BASH_REMATCH[5]}:${BASH_REMATCH[6]}"
  fi
}

#####################################
# Set metadata from filename
#####################################

setMetadataFromFilename() {
  local updated=0
  local skipped=0
  local target_dir="${1:-.}"

  echo "[*] Starting metadata update in: $target_dir"
  echo "[*] Processing all supported files..."
  echo ""

  while IFS= read -r -d '' file; do
    # Get just the filename for cleaner output
    filename=$(basename "$file")
    
    if ! isSupported "$file"; then
      echo "[⊘] Unsupported file type: $filename"
      ((skipped++))
      continue
    fi

    date_raw=$(extractDateFromFilename "$filename")
    if [[ -z "$date_raw" ]]; then
      echo "[⊘] Skipped (no date pattern found): $filename"
      ((skipped++))
      continue
    fi

    echo "[→] Processing: $filename → $date_raw"
    exif_date=$(toExifDate "$date_raw")

    # Update metadata based on video file
      exiftool -overwrite_original \
        -CreateDate="$exif_date" \
        -ModifyDate="$exif_date" \
        -TrackCreateDate="$exif_date" \
        -TrackModifyDate="$exif_date" \
        -MediaCreateDate="$exif_date" \
        -MediaModifyDate="$exif_date" \
        "$file" >/dev/null 2>&1

      if [[ $? -eq 0 ]]; then
        echo "[✓] Metadata updated: $filename"
        ((updated++))
      else
        echo "[!] Error updating metadata for: $filename"
        ((skipped++))
      fi

    # Also update file modification time to match
    touch -d "$date_raw" "$file" 2>/dev/null || {
      echo "[⚠] Warning: Could not set file timestamp for: $filename"
    }

  done < <(find "$target_dir" -maxdepth 1 -type f -print0)

  echo ""
  echo "========================================"
  echo "[✓] Metadata update complete!"
  echo "    Updated: $updated files"
  echo "    Skipped: $skipped files"
  echo "========================================"
}

#####################################
# MAIN
#####################################

echo "========================================"
echo "   Set Video Metadata from Filename"
echo "========================================"
echo ""

# Get folder from user
videos_folder=$(chooseFolder)
echo "[*] Changing directory to: $videos_folder"
cd "$videos_folder"
echo "[✓] Directory changed successfully"
echo ""

shopt -s nocaseglob

setMetadataFromFilename "."

echo ""
echo "[✓] Script completed successfully!"
