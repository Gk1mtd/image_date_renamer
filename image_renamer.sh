#!/bin/bash

# Don't exit on errors - handle them gracefully instead
# set -e

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

SUPPORTED_EXTENSIONS="jpg|jpeg|png|mp4|m4v"

#####################################
# UI
#####################################

chooseMode() {
  echo "[*] Showing mode selection dialog..." >&2
  mode=$(zenity --list \
    --title="Select Mode" \
    --text="Choose operation mode:" \
    --radiolist \
    --column="Select" --column="Mode" --column="Description" \
    TRUE "rename" "Rename files by EXIF creation date" \
    FALSE "update" "Update EXIF creation date from filename" \
    --width=500 --height=250)

  [[ -z "$mode" ]] && exit 0
  echo "[✓] Mode selected: $mode" >&2
  echo "$mode"
}

chooseFolder() {
  echo "[*] Showing folder selection dialog..." >&2
  local photos_folder=$(zenity \
    --file-selection \
    --directory \
    --confirm-overwrite \
    --title="Select Photos Folder")

  [[ -z "$photos_folder" ]] && exit 0
  echo "[✓] Folder selected: $photos_folder" >&2
  echo "$photos_folder"
}

#####################################
# Helpers
#####################################

isSupported() {
  [[ "$1" =~ \.($SUPPORTED_EXTENSIONS)$ ]]
}

toExifDate() {
  # input: YYYY-MM-DD HH:MM:SS
  echo "${1//-/:}"
}

#####################################
# Date extraction
#####################################

extractDateFromFilename() {
  local f="$1"

  # Pattern: YYYYMMDD_HHMMSS (e.g., 20210411_102628)
  if [[ "$f" =~ ([0-9]{8})[_-]([0-9]{6}) ]]; then
    echo "${BASH_REMATCH[1]:0:4}-${BASH_REMATCH[1]:4:2}-${BASH_REMATCH[1]:6:2} \
${BASH_REMATCH[2]:0:2}:${BASH_REMATCH[2]:2:2}:${BASH_REMATCH[2]:4:2}"
  # Pattern: YYYY-MM-DD-HHMMSS (e.g., signal-2021-08-08-205245)
  elif [[ "$f" =~ ([0-9]{4})-([0-9]{2})-([0-9]{2})-([0-9]{2})([0-9]{2})([0-9]{2}) ]]; then
    echo "${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${BASH_REMATCH[3]} \
${BASH_REMATCH[4]}:${BASH_REMATCH[5]}:${BASH_REMATCH[6]}"
  # Pattern: IMG-YYYYMMDD-* (e.g., IMG-20210104-WA0019)
  elif [[ "$f" =~ IMG-([0-9]{8})-.*\. ]]; then
    local datestr="${BASH_REMATCH[1]}"
    echo "${datestr:0:4}-${datestr:4:2}-${datestr:6:2} 12:00:00"
  fi
}

#####################################
# UPDATE MODE (filename → EXIF)
#####################################

updateFileDates() {
  echo "[*] Starting UPDATE mode (filename → EXIF dates)..." >&2
  local updated=0 skipped=0

  while IFS= read -r -d '' file; do
    # Remove leading ./ for cleaner output
    file="${file#./}"
    
    if ! isSupported "$file"; then
      echo "[⊘] Unsupported file type: $file" >&2
      ((skipped++))
      continue
    fi

    date_raw=$(extractDateFromFilename "$file")
    if [[ -z "$date_raw" ]]; then
      echo "[⊘] Skipped (no date found): $file" >&2
      ((skipped++))
      continue
    fi

    echo "[→] Processing: $file → $date_raw" >&2
    exif_date=$(toExifDate "$date_raw")

    if [[ "$file" =~ \.(mp4|m4v)$ ]]; then
      exiftool -overwrite_original \
        -CreateDate="$exif_date" \
        -ModifyDate="$exif_date" \
        -TrackCreateDate="$exif_date" \
        -TrackModifyDate="$exif_date" \
        -MediaCreateDate="$exif_date" \
        -MediaModifyDate="$exif_date" \
        "$file" >/dev/null 2>&1 || { echo "[!] Error updating $file" >&2; continue; }
    else
      exiftool -overwrite_original -AllDates="$exif_date" "$file" >/dev/null 2>&1 || { echo "[!] Error updating $file" >&2; continue; }
    fi

    touch -d "$date_raw" "$file" || { echo "[!] Error setting file timestamp for $file" >&2; continue; }
    ((updated++))
  done < <(find . -maxdepth 1 -type f -print0)

  echo "[✓] Update complete: $updated updated, $skipped skipped" >&2
  zenity --info --title="Done" --text="Updated: $updated\nSkipped: $skipped"
}

#####################################
# RENAME MODE (EXIF → filename)
#####################################

renamingFiles() {
  echo "[*] Starting RENAME mode (EXIF dates → filenames)..."
  local renamed=0
  
  while IFS= read -r -d '' file; do
    isSupported "$file" || continue

    ext="${file##*.}"
    
    # Try different EXIF tags based on file type
    if [[ "$file" =~ \.(mp4|m4v)$ ]]; then
      # For videos, try video-specific tags first
      base_date=$(exiftool -s -s -s -CreateDate "$file" 2>/dev/null)
      [[ -z "$base_date" ]] && base_date=$(exiftool -s -s -s -MediaCreateDate "$file" 2>/dev/null)
      [[ -z "$base_date" ]] && base_date=$(exiftool -s -s -s -TrackCreateDate "$file" 2>/dev/null)
    else
      # For images, use DateTimeOriginal
      base_date=$(exiftool -s -s -s -DateTimeOriginal "$file" 2>/dev/null)
    fi

    if [[ -z "$base_date" ]]; then
      ts=$(stat -c %Y "$file")
      base_date=$(date -d @"$ts" +"%Y:%m:%d")
    else
      base_date="${base_date%% *}"
    fi

    new_name="${base_date//:/-}.$ext"
    [[ "$file" == "./$new_name" ]] && continue

    i=1
    while [[ -e "$new_name" ]]; do
      new_name="${base_date//:/-}_$i.$ext"
      ((i++))
    done

    echo "[→] Renaming: $file → $new_name"
    mv "$file" "$new_name"
    ((renamed++))
  done < <(find . -maxdepth 1 -type f -print0)

  echo "[✓] Rename complete: $renamed files renamed"
  zenity --info --title="Done" --text="Renaming complete"
}

#####################################
# MAIN
#####################################

echo "========================================"
echo "   Image Date Renamer"
echo "========================================"
echo ""

mode=$(chooseMode)
photos_folder=$(chooseFolder)
echo "[*] Changing directory to: $photos_folder"
cd "$photos_folder"
echo "[✓] Directory changed successfully"
echo ""

shopt -s nocaseglob

if [[ "$mode" == "update" ]]; then
  updateFileDates
else
  renamingFiles
fi

echo ""
echo "[✓] Script completed successfully!"
