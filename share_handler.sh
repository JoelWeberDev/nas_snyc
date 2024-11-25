#!/bin/bash
# @Date: 2024/11/05
# @Description: This is the lock manager for shared files in our local nas.
# The share handler delegates what clients get to access a given file and 
# when they can read / write / modify. 

# Is file currently open
DIR="/home/joel/Development/nas/scripts/test_files"
FILE="open_test.txt"
APPS=( "vim" "nano" "gedit" "cat" "bash" )


# Check if the file is open by vim
is_file_open() {
    for APP in "${APPS[@]}" ; do
        if lsof -wc "vim" | grep "$FILE" > /dev/null 2>&1 ; then
            echo "The file ${FILE} is currently open by $APP."
            return 0
        else
            echo "The file ${FILE} is not open by $APP."
        fi
    done
    return 1
}

# if is_file_open ; then
#     echo "File open"
# fi



exit 0