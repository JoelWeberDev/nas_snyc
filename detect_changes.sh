#!/bin/bash
# Desciption: Here we check if any modifications have been made to our
# file system. This will be broken into 2 sub issues.
# 1. Have the file contents changed?
#   a. We do not need to determine what has changed inside the file, but rather
#       which file has changed
#   b. This could be hacked by byte checking, but this is still prone to the
#       occasional error.
#   c. We will do it the git way where we take the most recent metadata
#       from the stat function in bash we can get the last time modified. If the
#       most recent mod time differs from the current one, we will add the file to
#
# With this we can simply compare the last modification date with the current one
# 2. Has the fs structure changed at all?
# Please note that both of these cases can be similtaneously true.

FS_DIR="/home/joel/Development/nas/test_fs"
STATES_NAME="states.txt"

# Detect file modification
# date_string="2024-02-29 13:45:30.1234"
# if echo "$date_string" | grep -P '^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01]) ([01]\d|2[0-3]):([0-5]\d):([0-5]\d\.\d{4})$' >/dev/null; then
#     echo "Valid date format"
# else
#     echo "Invalid date format"
# fi
#

get_states() {
    echo "Reading $FS_DIR/$STATES_NAME :"
    cat "$FS_DIR/$STATES_NAME"
}

# get_states

line_by_line() {
    i=0
    ignore="^#"
    while IFS= read -r line; do
        echo "$i: $line"

        if [[ $line =~ $ignore ]]; then
            echo "Ignoring line $i"
        fi

        ((i++))
    done < "$FS_DIR/$STATES_NAME"
}

# line_by_line

append_line() {
    local fname=$1
    local line=$2

    echo "$line" >> "$fname"
}

# append_line "$FS_DIR/$STATES_NAME" "Legit line"

insert_line() {
    local file=$1
    local line_num=$2
    local text=$3

    # Insert text at specified line
    sed -i "${line_num}i\\${text}" "$file"
}

# insert_line "$FS_DIR/$STATES_NAME" 2 "inserted_line"
# get_states

get_line() {
    local file=$1
    local line_num=$2

    sed -n "$line_num p" "$file"
}

# get_line "$FS_DIR/$STATES_NAME" 2

# Write absent files to the states
iterate_files() {
    local fs_dir=$1

    if [ ! -e "$fs_dir" ]; then
        echo "$fs_dir does not exist"
    elif [ ! -d "$fs_dir" ]; then
        echo "$fs_dir is not directory"
    else
        for file in "$fs_dir"/*; do
            if [ -d "$file" ]; then
                echo "$file is a directory"
                iterate_files "$file"
            else
                echo "$file"
            fi
        done
    fi

}

iterate_files "$FS_DIR"

# Detect FS changes
