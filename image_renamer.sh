#!/bin/bash

# Prompt user to select the mode using Zenity
function chooseMode() {
  mode=$(zenity --list \
    --title="Select Mode" \
    --text="Choose operation mode:" \
    --radiolist \
    --column="Select" --column="Mode" --column="Description" \
    TRUE "rename" "Rename files by creation date" \
    FALSE "update" "Update file creation date from filename" \
    --width=500 --height=250)
  
  # Check if the user canceled mode selection
  if [[ -z "$mode" ]]; then
    echo "Mode selection canceled."
    exit 0
  fi
  
  echo "Selected mode: $mode"
}

# Prompt user to select the folder using Zenity
function chooseFolder() {
  photos_folder=$(zenity --file-selection --directory --title="Select Photos Folder")
  echo $photos_folder
  # Check if the user canceled folder selection
  if [[ -z "$photos_folder" ]]; then
    echo "Folder selection canceled."
    exit 0
  fi

  # Count the number of photo files in the folder
  photo_count=$(find "$photos_folder" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.m4v" -o -iname "*.mp4" \) | wc -l)
}

# Go to the selected photos folder
function goToPhotosFolder() {
  cd "$photos_folder" || exit
}

# Check if file is a supported media file
function isSupportedMediaFile() {
  local file="$1"
  if [[ -f "$file" && ( "$file" == *.jpg || "$file" == *.jpeg || "$file" == *.png || "$file" == *.m4v || "$file" == *.mp4 ) ]]; then
    return 0
  fi
  return 1
}

# Extract date from filename using various patterns
function extractDateFromFilename() {
  local filename="$1"
  local date_string=""
  
  # Pattern 1: YYYYMMDD_HHMMSS (e.g., 20200904_141034.jpg)
  if [[ "$filename" =~ ([0-9]{8})_([0-9]{6}) ]]; then
    local date_part="${BASH_REMATCH[1]}"
    local time_part="${BASH_REMATCH[2]}"
    date_string="${date_part:0:4}-${date_part:4:2}-${date_part:6:2} ${time_part:0:2}:${time_part:2:2}:${time_part:4:2}"
  # Pattern 2: IMG-YYYYMMDD-... or VID-YYYYMMDD-... (e.g., IMG-20200905-WA0000.jpeg)
  elif [[ "$filename" =~ (IMG|VID)-([0-9]{8}) ]]; then
    local date_part="${BASH_REMATCH[2]}"
    date_string="${date_part:0:4}-${date_part:4:2}-${date_part:6:2}"
  # Pattern 3: Pxl YYYYMMDD HHMMSS (e.g., Pxl 20210815 155658793.m4v)
  elif [[ "$filename" =~ [Pp]xl[[:space:]]([0-9]{8})[[:space:]]([0-9]{6}) ]]; then
    local date_part="${BASH_REMATCH[1]}"
    local time_part="${BASH_REMATCH[2]}"
    date_string="${date_part:0:4}-${date_part:4:2}-${date_part:6:2} ${time_part:0:2}:${time_part:2:2}:${time_part:4:2}"
  # Pattern 4: signal-YYYY-MM-DD-HHMMSS (e.g., signal-2021-12-27-175024 (4).jpeg)
  elif [[ "$filename" =~ signal-([0-9]{4})-([0-9]{2})-([0-9]{2})-([0-9]{6}) ]]; then
    date_string="${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${BASH_REMATCH[3]} ${BASH_REMATCH[4]:0:2}:${BASH_REMATCH[4]:2:2}:${BASH_REMATCH[4]:4:2}"
  # Pattern 5: Screenshot_YYYYMMDD-HHMMSS (e.g., Screenshot_20210120-072910_Tabs.jpg)
  elif [[ "$filename" =~ Screenshot_([0-9]{8})-([0-9]{6}) ]]; then
    local date_part="${BASH_REMATCH[1]}"
    local time_part="${BASH_REMATCH[2]}"
    date_string="${date_part:0:4}-${date_part:4:2}-${date_part:6:2} ${time_part:0:2}:${time_part:2:2}:${time_part:4:2}"
  # Pattern 6: YYYY-MM-DD HH.MM.SS (e.g., 2014-01-05 20.05.24.jpg)
  elif [[ "$filename" =~ ([0-9]{4})-([0-9]{2})-([0-9]{2})[[:space:]]([0-9]{2})\.([0-9]{2})\.([0-9]{2}) ]]; then
    date_string="${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${BASH_REMATCH[3]} ${BASH_REMATCH[4]}:${BASH_REMATCH[5]}:${BASH_REMATCH[6]}"
  # Pattern 7: IMG_YYYYMMDD_HHMMSS (e.g., IMG_20140114_161758.jpg)
  elif [[ "$filename" =~ IMG_([0-9]{8})_([0-9]{6}) ]]; then
    local date_part="${BASH_REMATCH[1]}"
    local time_part="${BASH_REMATCH[2]}"
    date_string="${date_part:0:4}-${date_part:4:2}-${date_part:6:2} ${time_part:0:2}:${time_part:2:2}:${time_part:4:2}"
  fi
  
  echo "$date_string"
}

# Update file creation date from filename
function updateFileDates() {
  local updated_count=0
  local skipped_count=0
  for file in *; do
    if isSupportedMediaFile "$file"; then
      date_string=$(extractDateFromFilename "$file")
      
      if [[ -n "$date_string" ]]; then
        # Update file modification and access time
        if touch -d "$date_string" "$file" 2>/dev/null; then
          echo "Updated $file to $date_string"
          ((updated_count++))
        else
          echo "Warning: Failed to update $file - invalid date format: $date_string"
        fi
      else
        echo "Skipped $file - no date pattern found"
        ((skipped_count++))
      fi
    fi
  done
  echo "Updated $updated_count file(s), skipped $skipped_count file(s)"
}

# Loop through each file in the folder
function renamingFiles() {
  for file in *; do
    if isSupportedMediaFile "$file"; then
      extractFileExtension "$file"

      # Get the creation timestamp of the file
      creation_timestamp=$(stat -c %Y "$file")

      # Convert the creation timestamp to a formatted date
      formatted_date=$(date -d @"$creation_timestamp" +"%Y-%m-%d")

      # Generate the new name with the formatted creation date
      new_name_with_time="$formatted_date.$postfix"

      # Check if the new name already exists
      if [[ -e "$new_name_with_time" ]]; then
        index=1
        while [[ -e "${new_name_with_time%.*}_$index.$postfix" ]]; do
          ((index++))
        done
        new_name_with_time="${new_name_with_time%.*}_$index.$postfix"
      fi

      # Rename the file
      mv "$file" "$new_name_with_time"
      echo "Renamed $file to $new_name_with_time"
    fi
  done
}

# Extract the file extension
function extractFileExtension() {
  file_extension="${1##*.}"

  # Check if the file is a media file and store the postfix in a variable
  if [[ "$1" == *.jpg || "$1" == *.jpeg || "$1" == *.png || "$1" == *.m4v || "$1" == *.mp4 ]]; then
    postfix="$file_extension"
  fi
}

# Display a message when the script is done
function displayMessage() {
  local message="$1"
  zenity --info --title="Script Complete" --text="$message" --width=200 --height=100
}

chooseMode
chooseFolder
goToPhotosFolder

if [[ "$mode" == "rename" ]]; then
  renamingFiles
  displayMessage "Photo renaming complete!"
elif [[ "$mode" == "update" ]]; then
  updateFileDates
  displayMessage "File date update complete!"
fi
