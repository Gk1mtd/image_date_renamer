# Photo Renaming Script

This script is a Bash shell script that renames photo files based on their creation dates. It utilizes Zenity for folder selection.

## Prerequisites

- Bash shell
- Zenity (GTK+ dialog utility) installed (mostly installed already)

## Usage

1. Make sure you have the prerequisites installed on your system.

2. Open a terminal and navigate to the directory where the script is located.

3. Run the script by executing the following command:

   ```bash
   bash photo_renaming_script.sh
   ```

4. A Zenity dialog will appear, prompting you to select the folder that contains the photos you want to rename. Use the file browser to navigate to the desired folder and click "Open".

5. The script will count the number of photo files (with extensions .jpg, .jpeg, and .png) in the selected folder.

6. It will then loop through each file in the folder and check if it is a photo file based on the file extensions.

7. For each photo file, the script will extract the file extension and retrieve the creation timestamp of the file.

8. The creation timestamp will be converted to a formatted date in the format YYYY-MM-DD.

9. The script will generate a new name for the file by combining the formatted creation date and the original file extension.

10. If the new name already exists in the folder, an index number will be appended to ensure uniqueness.

11. The file will be renamed using the new name.

12. After all photo files have been renamed, a Zenity message dialog will be displayed, indicating that the renaming process is complete.

## Notes

- Only files with the extensions .jpg, .jpeg, and .png are considered as photo files. You can modify the condition in the script to include additional file extensions if needed.
- The script utilizes Zenity for folder selection and progress display. Ensure that Zenity is installed on your system for the script to work correctly.
