#!/bin/bash

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
  photo_count=$(find "$photos_folder" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | wc -l)
}

# Go to the selected photos folder
function goToPhotosFolder() {
  cd "$photos_folder" || exit
}

# Loop through each file in the folder
function renamingFiles() {
  for file in *; do
    # Check if the file is a photo (you can modify the condition as per your requirements)
    if [[ "$file" == *.jpg || "$file" == *.jpeg || "$file" == *.png ]]; then
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

  # Check if the file is a photo and store the postfix in a variable
  if [[ "$1" == *.jpg || "$1" == *.jpeg || "$1" == *.png ]]; then
    postfix="$file_extension"
  fi
}

# Display a message when the script is done
function displayMessage() {
  zenity --info --title="Script Complete" --text="Photo renaming complete!" --width=200 --height=100
}

chooseFolder
goToPhotosFolder
renamingFiles
displayMessage
