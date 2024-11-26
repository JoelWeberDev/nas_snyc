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
# 
# TODO:
# 1. Create means for modification of the line in the states file
# 2. Write processing functions for the states file 
#   - Date compare
#   - Update line to new date
#   - Is line in states file
#   - Write task to ledger
# 3. Create ledger file and its writing functions (new script)

FS_DIR="/home/joel/Development/nas/test_fs"
STATES_NAME="states.txt"

# File metadata reading
read_metadata() {
    local file=$1
    local metadata=$(stat "$file")
    echo "$metadata"
}

# read_metadata "$FS_DIR/$STATES_NAME"

date_cmp() {
    local date1=$1
    local date2=$2

    if [ "$date1" == "$date2" ]; then
        # echo "Dates are equal"
        # echo "0"
        return 0
    elif [ "$date1" -gt "$date2" ]; then
        # echo "Date 1 is greater"
        # echo "1"
        return 1
    else
        # echo "Date 2 is greater"
        # echo "-1"
        return 2
    fi
}

parse_date() {
    # Parses date string into seconds
    local date_string=$1
    local date=$(date -d "$date_string" +"%s")
    echo "$date"
}

reformat_date() {
    # Reformat date string
    local timestamp=$1
    local date=$(date -d "@$timestamp" +"%Y-%m-%d %H:%M:%S")
    echo "$date"
}

get_mod_time() {
    # gets the date of the last modification for the given file
    local file=$1
    
    if [ ! -e "$file" ]; then
        echo "$file does not exist"
        return 1
    fi

    local modify_time=$(stat -c %y "$file")

    # echo "Modify time: $modify_time"

    # Convert to date
    local modify_date=$(parse_date "$modify_time")
    
    echo "$modify_date"

    return 0

    # new_date=$(($modify_date + 10))
    # # readj_date=$(date -d "@$new_date" +"%Y-%m-%d %H:%M:%S")
    # m10_date=$((new_date - 10))
    # echo "Readjusted date: $m10_date"
    # echo "+10 date: $new_date"
    # echo "Modify date: $modify_date"

    # # # Compare dates
    # date_cmp "$modify_date" "$new_date"
    # cmp1=$?
    # date_cmp "$new_date" "$modify_date"
    # cmp2=$?
    # date_cmp "$modify_date" "$m10_date"
    # cmp3=$?

    # echo "cmp1: $cmp1"
    # echo "cmp2: $cmp2"
    # echo "cmp3: $cmp3"
}

# get_mod_time "$FS_DIR/$STATES_NAME"

get_states() {
    echo "Reading $FS_DIR/$STATES_NAME :"
    cat "$FS_DIR/$STATES_NAME"
}

# get_states

parse_states_line() {
    # Takes a line read from the states file and parses it into a file name and date of last modification
    local line_string=$1

    # each line should have formate of: "file_name,mod_date"
    # fname=$(echo "$line_string" | cut -d ',' -f 1)
    IFS="," read -ra parts <<< "$line_string"

    if [ ${#parts[@]} == 2 ]; then
        local fname="${parts[0]}"
        local mod_date="${parts[1]}"

        echo "$fname"
        echo "$mod_date"
    else
        echo "Invalid line format"
        return 1
    fi

}


line_by_line() {
    # Iterates through the state file line by line and executes a function on each line
    # The process function must take the file name and the date of last modification as aguments
    local process_func=$1
    i=0
    ignore="^#"
    ws="^[[:space:]]*$"
    while IFS= read -r line || [[ -n "$line" ]]; do

        if [[ $line =~ $ignore || $line =~ $ws ]]; then
            echo "Ignoring line $i"
        else
            echo "line $i: $line"
            local output
            output=$(parse_states_line "$line")
            local valid=$?
            
            if [ $valid -eq 1 ]; then
                echo "Invalid line"
                continue
            else
                # Since the line is valid we will run the process function on the output
                local fname=$(echo "$output" | sed -n '1p')
                local mod_date=$(echo "$output" | sed -n '2p')
                
                process_func "$fname" "$mod_date"
                
            fi
        fi

        ((i++))
    done < "$FS_DIR/$STATES_NAME"
}

line_by_line

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

# iterate_files "$FS_DIR"



# Detect FS changes

