# Photo Renaming Script

This script is a Bash shell script that provides two modes for managing photo and video files based on dates. It utilizes Zenity for folder selection and mode selection.

## Prerequisites

- Bash shell
- Zenity (GTK+ dialog utility) installed (mostly installed already)

## Modes

The script offers two operation modes:

### Mode 1: Rename files by creation date
- Renames photo and video files based on their file system creation/modification dates
- Generates filenames in the format: YYYY-MM-DD.ext (e.g., 2020-09-04.jpg)
- Automatically handles duplicate names by appending an index number

### Mode 2: Update file creation date from filename
- Extracts dates from filenames and updates the file's modification/creation timestamp
- Supports various filename patterns including:
  - `20200904_141034.jpg` (YYYYMMDD_HHMMSS)
  - `IMG-20200905-WA0000.jpeg` (IMG-YYYYMMDD-...)
  - `VID-20210228-WA0011.m4v` (VID-YYYYMMDD-...)
  - `Pxl 20210815 155658793.m4v` (Pxl YYYYMMDD HHMMSS...)
  - `signal-2021-12-27-175024 (4).jpeg` (signal-YYYY-MM-DD-HHMMSS)
  - `Screenshot_20210120-072910_Tabs.jpg` (Screenshot_YYYYMMDD-HHMMSS_...)
  - `2014-01-05 20.05.24.jpg` (YYYY-MM-DD HH.MM.SS)
  - `IMG_20140114_161758.jpg` (IMG_YYYYMMDD_HHMMSS)
- Files without recognizable date patterns are skipped (no changes made)

## Usage

1. Make sure you have the prerequisites installed on your system.

2. Open a terminal and navigate to the directory where the script is located.

3. Run the script by executing the following command:

   ```bash
   bash image_renamer.sh
   ```

4. A mode selection dialog will appear. Choose one of the two modes:
   - **Rename files by creation date**: Renames files based on their metadata timestamps
   - **Update file creation date from filename**: Updates file timestamps based on dates found in filenames

5. After selecting a mode, a folder selection dialog will appear. Use the file browser to navigate to the desired folder containing your media files and click "Open".

6. The script will process all media files in the selected folder based on the chosen mode:
   - **Mode 1**: Files will be renamed to YYYY-MM-DD format
   - **Mode 2**: File timestamps will be updated based on their filenames

7. After processing is complete, a message dialog will appear indicating completion.

## Notes

- Supported file extensions: .jpg, .jpeg, .png, .m4v, and .mp4
- The script utilizes Zenity for mode selection, folder selection, and completion dialogs. Ensure that Zenity is installed on your system for the script to work correctly.
- In Mode 2 (Update file creation date from filename), files without recognizable date patterns in their names will be skipped and left unchanged.
- The script processes only files in the selected folder (not subdirectories).
