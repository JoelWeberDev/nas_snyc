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
# Also please note that all the file paths will be absolute paths
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
LEDGER="ledger.txt"

### Date functions ###

# File metadata reading
read_metadata() {
    local file=$1
    local metadata=$(stat "$file")
    echo "$metadata"
}

# read_metadata "$FS_DIR/$LEDGER"

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
}

# get_mod_time "$FS_DIR/$LEDGER"

get_states() {
    echo "Reading $FS_DIR/$LEDGER:"
    cat "$FS_DIR/$LEDGER"
}

# get_states

### Ledger interaction functions ###

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

print_line() {
    local file=$1
    local mod_date=$2
    local line_num=$3
    local args=("$@")

    echo "File: $file"
    echo "Mod date: $mod_date"
    echo "Line number: $line_num"
    echo "Args: ${args[@]:3}"

    return 0
}

cmp_file_name() {
    # Compares the file name in the states file with the given file name
    local ledger_fname=$1
    local mod_date=$2
    local line_num=$3
    local fname=$4

    # local states_fname=$(parse_states_line "$states_file" | sed -n '1p')

    if [ "$ledger_fname" == "$fname" ]; then
        return 2
    else
        return 0
    fi
}

queue_changed() {
    # This takes the date corrsponding to a file date and queues it for syncing
    local ledger_fname=$1
    local mod_date=$2
    local line_num=$3
    local other_date=$4

    date_cmp "$mod_date" "$other_date"
    local cmp=$?    

    if [ $cmp -eq 2 ]; then
        echo "File has been modified"
        # Queue the file for syncing
    else
        echo "File has not been modified"
    fi

    return 0
}

line_by_line() {
    # Iterates through the state file line by line and executes a function on each line
    # The process function must take the file name, the mod date and line number as arguments
    # Process function returns are as follows:
    # 0: Success
    # 1: Failure
    # 2: Return true from line_by_line
    # 3: Return false from line_by_line
    local file=$1
    local process_func=$2
    local args=("$@")
    local i=0
    local ignore="^#"
    local ws="^[[:space:]]*$"
    
    if [ ! -e "$file" ]; then
        echo "$file does not exist"
        return 1
    fi  

    # Read the file into an array to avoid issues with modifying the file while reading it
    mapfile -t lines < "$file"

    for line in "${lines[@]}"; do

        if [[ ! ($line =~ $ignore || $line =~ $ws) ]]; then
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
                
                # Call the processing function on the line
                "${process_func}" "$fname" "$mod_date" "$i" "${args[@]:2}"

                # Check the return value of the processing function
                local ret=$?
                if [ $ret -eq 2 ]; then
                    return 2 # Return true
                elif [ $ret -eq 3 ]; then
                    return 3 # Return false
                fi
            fi
        fi

        ((i++))
    done

    return 0
}

append_line() {
    local fname=$1
    local line=$2

    echo "$line" >> "$fname"
}

# append_line "$FS_DIR/$LEDGER" "Legit line"

insert_line() {
    # insert line at specified line number (line number is 1 indexed)
    # when inserting a line the current line at that number is pushed down
    local file=$1
    local line_num=$2
    local text=$3

    # if the line number is greater than the number of lines in the file, append the text to the end of the file
    if [ $line_num -gt $(wc -l < "$file") ]; then
        append_line "$file" "$text"

    else
        # Insert text at specified line 
        sed -i "${line_num}i\\${text}" "$file"
    fi

}

search_insert_pos() {
    # Binary searches the file for the correct position to insert the line
    # If the line already exists, the function will return the line number
    # If the line does not exist, the function will return the line number to insert the line
    local search_name=$1
    local found=$2

    mapfile -t lines < "$FS_DIR/$LEDGER"

    local low=0
    # local high=$(wc -l < "$FS_DIR/$LEDGER")
    local high=${#lines[@]}

    # Find the first entry that is not comments or whitespace
    local ignore="^#"
    local ws="^[[:space:]]*$"
    
    while [[ (${lines[low]} =~ $ignore || ${lines[low]} =~ $ws) && $low -lt $high ]]; do
        # echo ${lines[low]}
        ((low++))
    done

    while [[ (${lines[high]} =~ $ignore || ${lines[high]} =~ $ws) && $low -lt $high ]]; do
        # echo ${lines[high]}
        ((high--))
    done

    while [[ $low -le $high ]]; do
        local mid=$((low + (high - low) / 2))
        local mid_line=${lines[mid]}

        if [[ mid_line =~ $ws ]]; then
            ((mid++))
        fi

        local mid_name=$(parse_states_line "$mid_line" | sed -n '1p')

        if [[ "$mid_name" == "$search_name" ]]; then
            echo "true" "$(($low + 1))"
            # return $(($mid + 1))

        elif [[ "$mid_name" < "$search_name" ]]; then
            low=$((mid + 1))
        else
            high=$((mid - 1))
        fi
    done

    echo "false" "$(($low + 1))"
    # return $(($low + 1))
}

# fname="bedgee.txt"
# found=$(search_insert_pos "$fname")
# insert_line "$FS_DIR/$LEDGER" $? "$fname,420420"



get_line() {
    local file=$1
    local line_num=$2

    sed -n "$line_num p" "$file"
}

# get_line "$FS_DIR/$LEDGER" 2

format_file_line() {
    local file=$1

    # Get the date of the last modification from the file
    local mod_date=$(get_mod_time "$FS_DIR/$file")

    # Format the date
    echo "$file,$mod_date"
    return 0
}

# Write absent files to the states
iterate_files() {
    local base_dir=$1

    if [ ! -e "$base_dir" ]; then
        echo "$base_dir does not exist"
    elif [ ! -d "$base_dir" ]; then
        echo "$base_dir is not directory"
    else
        for file in "$base_dir"/*; do
            if [ -d "$file" ]; then
                iterate_files "$file"
            else
                local relative_path="${file#$FS_DIR/}"
                # line_by_line "$FS_DIR/$LEDGER" "cmp_file_name" "$relative_path"
                read found insert_index < <(search_insert_pos "$relative_path")
                echo "Found: $found"
                echo "Insert index: $insert_index"

                if [[ $found == "false" ]]; then
                    # File is not in the states file
                    local line=$(format_file_line "$relative_path")
                    insert_line "$FS_DIR/$LEDGER" $insert_index "$line"
                    # append_line "$FS_DIR/$LEDGER" "$line"
                fi
            fi
        done
    fi

}

iterate_files "$FS_DIR" 

